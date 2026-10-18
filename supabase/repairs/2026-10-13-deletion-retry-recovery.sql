-- Dev recovery repair: unchanged owner scope and service-only worker grants.
begin;
lock table ff_private.workspaces, ff_private.deletion_jobs in share row exclusive mode;
do $$ begin
  if exists(select 1 from ff_private.deletion_jobs) then
    raise exception 'Existing deletion jobs require operator review' using errcode='55000';
  end if;
end $$;
alter table ff_private.deletion_jobs add column if not exists last_attempt_at timestamptz;
create index if not exists ff_deletion_retry_order on ff_private.deletion_jobs(last_attempt_at,created_at,id)
  where state in ('pending','running');
create or replace function ff_private.claim_deletions(p_limit integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype; result jsonb := '[]'::jsonb;
begin
  if p_limit is null or p_limit not between 1 and 3 then
    raise exception 'Invalid worker limit' using errcode = '22023';
  end if;
  for job in select j.* from ff_private.deletion_jobs j join ff_private.workspaces w on w.id = j.workspace_id
    where j.state in ('pending','running') and (j.lease_until is null or j.lease_until <= clock_timestamp())
      and w.deleting and w.owner_id = j.user_id
    order by j.last_attempt_at nulls first, j.created_at, j.id limit p_limit for update of j skip locked loop
    update ff_private.deletion_jobs set state = 'running', attempts = attempts + 1,
      last_attempt_at = clock_timestamp(),
      lease_id = gen_random_uuid(), lease_until = clock_timestamp() + interval '2 minutes', last_error_code = null
      where id = job.id returning * into job;
    result := result || jsonb_build_array(ff_private.deletion_job_json(job));
  end loop;
  return result;
end $$;
create or replace function ff_private.deletion_phase(p_job uuid, p_lease uuid, p_phase text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype;
begin
  job := ff_private.require_deletion_job(p_job, p_lease);
  if p_phase = 'photos' then
    if exists(select 1 from storage.objects where bucket_id = 'farrierflow-photos'
      and lower(split_part(name, '/', 1)) = job.workspace_id::text) then
      raise exception 'Photo cleanup not confirmed' using errcode = '23514';
    end if;
    update ff_private.deletion_jobs set photos_removed = true where id = p_job returning * into job;
  elsif p_phase = 'records' then
    if not job.photos_removed then raise exception 'Photos remain' using errcode = '23514'; end if;
    delete from ff_private.photo_manifest where workspace_id = job.workspace_id;
    delete from ff_private.records where workspace_id = job.workspace_id;
    delete from ff_private.commits where workspace_id = job.workspace_id;
    update ff_private.deletion_jobs set records_removed = true where id = p_job returning * into job;
  elsif p_phase = 'apple' then
    if not job.records_removed then raise exception 'Records remain' using errcode = '23514'; end if;
    update ff_private.deletion_jobs set apple_revoked = true, encrypted_apple_token = null
      where id = p_job returning * into job;
  elsif p_phase = 'ready' then
    if not job.photos_removed or not job.records_removed or not job.apple_revoked
       or exists(select 1 from storage.objects where bucket_id = 'farrierflow-photos'
         and lower(split_part(name, '/', 1)) = job.workspace_id::text) then
      raise exception 'Cleanup not ready' using errcode = '23514';
    end if;
  else raise exception 'Invalid deletion phase' using errcode = '22023'; end if;
  return ff_private.deletion_job_json(job);
end $$;
create or replace function ff_private.photo_write_allowed(p_name text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare workspace uuid;
begin
  if not ff_private.photo_allowed(p_name) then return false; end if;
  workspace := split_part(p_name, '/', 1)::uuid;
  -- Share locks allow concurrent uploads but serialize their authorization
  -- against sync tombstones and deletion queueing's workspace update lock.
  perform 1 from ff_private.workspaces where id = workspace for share;
  return ff_private.photo_allowed(p_name);
end $$;
revoke all on function ff_private.photo_write_allowed(text) from public,anon,authenticated,service_role;
grant execute on function ff_private.photo_write_allowed(text) to authenticated;
alter policy ff_photo_insert on storage.objects
  with check (bucket_id='farrierflow-photos' and ff_private.photo_write_allowed(name));
commit;
