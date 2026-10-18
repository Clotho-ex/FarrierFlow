-- Desired worker contract; install after solo_sync.sql. All privileged entry
-- points are service-role-only. No client can assert fresh Apple proof here.
begin;
create index ff_deletion_retry_order on ff_private.deletion_jobs(last_attempt_at,created_at,id)
  where state in ('pending','running');
grant usage on schema ff_private to service_role;
create table ff_private.deletion_receipts (
  id uuid primary key,
  receipt_hash text not null unique check (receipt_hash ~ '^[a-f0-9]{64}$'),
  completed_at timestamptz not null default now()
);
alter table ff_private.deletion_receipts enable row level security;
revoke all on table ff_private.deletion_receipts from public, anon, authenticated, service_role;

create function ff_private.deletion_owner(p_workspace uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid; subject text;
begin
  perform ff_private.require_access(p_workspace);
  actor := ff_private.actor();
  if not exists(select 1 from ff_private.workspaces where id = p_workspace and owner_id = actor)
     or (select count(*) from ff_private.memberships where workspace_id = p_workspace and revoked_at is null) <> 1 then
    raise exception 'Solo owner required' using errcode = '42501';
  end if;
  select identity_data->>'sub' into subject from auth.identities
    where user_id = actor and provider = 'apple';
  if subject is null or length(subject) not between 1 and 255 then
    raise exception 'Apple identity required' using errcode = '42501';
  end if;
  return jsonb_build_object('accountID', actor, 'sessionID', auth.jwt()->>'session_id', 'appleSubject', subject);
end $$;

create function ff_private.queue_deletion(p_account uuid, p_session uuid, p_workspace uuid,
  p_operation uuid, p_receipt_hash text, p_token jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare w ff_private.workspaces%rowtype; job ff_private.deletion_jobs%rowtype;
begin
  if p_account is null or p_session is null or p_workspace is null or p_operation is null
     or p_receipt_hash is null or p_receipt_hash !~ '^[a-f0-9]{64}$'
     or p_token is null or jsonb_typeof(p_token) <> 'object'
     or (select count(*) from jsonb_object_keys(p_token)) <> 3
     or p_token->>'version' is distinct from '1'
     or coalesce(p_token->>'iv','') !~ '^[A-Za-z0-9_-]{16}$'
     or length(coalesce(p_token->>'ciphertext','')) not between 23 and 21867
     or coalesce(p_token->>'ciphertext','') !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'Invalid deletion request' using errcode = '22023';
  end if;
  select * into w from ff_private.workspaces where id = p_workspace for update;
  if w.id is null or w.owner_id is distinct from p_account then
    raise exception 'Owner required' using errcode = '42501';
  end if;
  select * into job from ff_private.deletion_jobs where id = p_operation;
  if found then
    if job.user_id is distinct from p_account or job.workspace_id is distinct from p_workspace
       or job.receipt_hash is distinct from p_receipt_hash then
      raise exception 'Deletion identity reused' using errcode = '22023';
    end if;
    return jsonb_build_object('jobID', job.id, 'state', 'pending');
  end if;
  if w.deleting or not exists(select 1 from auth.sessions where id = p_session and user_id = p_account)
     or not exists(select 1 from ff_private.memberships where workspace_id = p_workspace
       and user_id = p_account and role = 'owner' and revoked_at is null)
     or (select count(*) from ff_private.memberships where workspace_id = p_workspace and revoked_at is null) <> 1 then
    raise exception 'Active solo owner session required' using errcode = '42501';
  end if;
  insert into ff_private.deletion_jobs(id, workspace_id, user_id, receipt_hash, encrypted_apple_token)
    values(p_operation, p_workspace, p_account, p_receipt_hash, p_token);
  update ff_private.workspaces set deleting = true where id = p_workspace;
  update ff_private.memberships set revoked_at = now() where workspace_id = p_workspace;
  return jsonb_build_object('jobID', p_operation, 'state', 'pending');
end $$;

create function ff_private.deletion_job_json(p_job ff_private.deletion_jobs) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('jobID', (p_job).id, 'accountID', (p_job).user_id,
    'workspaceID', (p_job).workspace_id, 'leaseID', (p_job).lease_id,
    'photosRemoved', (p_job).photos_removed, 'recordsRemoved', (p_job).records_removed,
    'appleRevoked', (p_job).apple_revoked, 'encryptedAppleToken', (p_job).encrypted_apple_token)
$$;
create function ff_private.require_deletion_job(p_job uuid, p_lease uuid)
returns ff_private.deletion_jobs language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype;
begin
  select j.* into job from ff_private.deletion_jobs j join ff_private.workspaces w on w.id = j.workspace_id
    where j.id = p_job and j.lease_id = p_lease and j.lease_until > clock_timestamp()
      and j.state = 'running' and w.deleting and w.owner_id = j.user_id for update of j;
  if not found then raise exception 'Deletion lease unavailable' using errcode = '55000'; end if;
  return job;
end $$;
create function ff_private.claim_deletions(p_limit integer) returns jsonb
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
create function ff_private.deletion_photos(p_job uuid, p_lease uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype; result jsonb;
begin
  job := ff_private.require_deletion_job(p_job, p_lease);
  select coalesce(jsonb_agg(name order by name), '[]'::jsonb) into result from (
    select name from storage.objects where bucket_id = 'farrierflow-photos'
      and lower(split_part(name, '/', 1)) = job.workspace_id::text order by name limit 200
  ) photos;
  return result;
end $$;
create function ff_private.deletion_phase(p_job uuid, p_lease uuid, p_phase text) returns jsonb
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
create function ff_private.deletion_failed(p_job uuid, p_lease uuid, p_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype;
begin
  job := ff_private.require_deletion_job(p_job, p_lease);
  if p_code is null or p_code not in ('cleanup_unconfirmed','more_photos_pending') then
    raise exception 'Invalid error code' using errcode = '22023';
  end if;
  update ff_private.deletion_jobs set state = 'pending', lease_id = null, lease_until = null,
    last_error_code = p_code where id = p_job;
end $$;
create function ff_private.finish_deletion(p_job uuid, p_lease uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare job ff_private.deletion_jobs%rowtype;
begin
  job := ff_private.require_deletion_job(p_job, p_lease);
  if not job.photos_removed or not job.records_removed or not job.apple_revoked
     or exists(select 1 from auth.users where id = job.user_id)
     or exists(select 1 from auth.sessions where user_id = job.user_id)
     or exists(select 1 from storage.objects where bucket_id = 'farrierflow-photos'
       and lower(split_part(name, '/', 1)) = job.workspace_id::text)
     or exists(select 1 from ff_private.records where workspace_id = job.workspace_id)
     or exists(select 1 from ff_private.commits where workspace_id = job.workspace_id)
     or exists(select 1 from ff_private.photo_manifest where workspace_id = job.workspace_id) then
    raise exception 'Deletion not complete' using errcode = '23514';
  end if;
  -- The unlinked random receipt contains no account ID or business content.
  insert into ff_private.deletion_receipts(id, receipt_hash) values(job.id, job.receipt_hash);
  delete from ff_private.deletion_jobs where id = p_job;
  delete from ff_private.devices where workspace_id = job.workspace_id;
  delete from ff_private.memberships where workspace_id = job.workspace_id;
  delete from ff_private.workspaces where id = job.workspace_id;
end $$;
create function ff_private.deletion_status(p_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare job_id uuid;
begin
  if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'Invalid receipt' using errcode = '22023'; end if;
  select id into job_id from ff_private.deletion_receipts where receipt_hash = p_hash;
  if found then return jsonb_build_object('jobID', job_id, 'state', 'complete'); end if;
  select id into job_id from ff_private.deletion_jobs where receipt_hash = p_hash;
  if found then return jsonb_build_object('jobID', job_id, 'state', 'pending'); end if;
  return jsonb_build_object('state', 'notFound');
end $$;

create function public.ff_deletion_owner(p_workspace uuid) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.deletion_owner(p_workspace) $$;
create function public.ff_queue_deletion(p_account uuid,p_session uuid,p_workspace uuid,p_operation uuid,p_receipt_hash text,p_token jsonb) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.queue_deletion(p_account,p_session,p_workspace,p_operation,p_receipt_hash,p_token) $$;
create function public.ff_claim_deletions(p_limit integer) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.claim_deletions(p_limit) $$;
create function public.ff_deletion_photos(p_job uuid,p_lease uuid) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.deletion_photos(p_job,p_lease) $$;
create function public.ff_deletion_phase(p_job uuid,p_lease uuid,p_phase text) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.deletion_phase(p_job,p_lease,p_phase) $$;
create function public.ff_deletion_failed(p_job uuid,p_lease uuid,p_code text) returns void language sql security invoker set search_path = '' as $$ select ff_private.deletion_failed(p_job,p_lease,p_code) $$;
create function public.ff_finish_deletion(p_job uuid,p_lease uuid) returns void language sql security invoker set search_path = '' as $$ select ff_private.finish_deletion(p_job,p_lease) $$;
create function public.ff_deletion_status(p_hash text) returns jsonb language sql security invoker set search_path = '' as $$ select ff_private.deletion_status(p_hash) $$;

revoke all on function ff_private.deletion_owner(uuid), public.ff_deletion_owner(uuid) from public, anon, authenticated, service_role;
grant execute on function ff_private.deletion_owner(uuid), public.ff_deletion_owner(uuid) to authenticated;
revoke all on function ff_private.queue_deletion(uuid,uuid,uuid,uuid,text,jsonb), ff_private.deletion_job_json(ff_private.deletion_jobs),
  ff_private.require_deletion_job(uuid,uuid), ff_private.claim_deletions(integer), ff_private.deletion_photos(uuid,uuid),
  ff_private.deletion_phase(uuid,uuid,text), ff_private.deletion_failed(uuid,uuid,text), ff_private.finish_deletion(uuid,uuid),
  ff_private.deletion_status(text) from public, anon, authenticated, service_role;
revoke all on function public.ff_queue_deletion(uuid,uuid,uuid,uuid,text,jsonb), public.ff_claim_deletions(integer),
  public.ff_deletion_photos(uuid,uuid), public.ff_deletion_phase(uuid,uuid,text), public.ff_deletion_failed(uuid,uuid,text),
  public.ff_finish_deletion(uuid,uuid), public.ff_deletion_status(text) from public, anon, authenticated, service_role;
grant execute on function ff_private.queue_deletion(uuid,uuid,uuid,uuid,text,jsonb), ff_private.claim_deletions(integer),
  ff_private.deletion_photos(uuid,uuid), ff_private.deletion_phase(uuid,uuid,text), ff_private.deletion_failed(uuid,uuid,text),
  ff_private.finish_deletion(uuid,uuid), ff_private.deletion_status(text), public.ff_queue_deletion(uuid,uuid,uuid,uuid,text,jsonb),
  public.ff_claim_deletions(integer), public.ff_deletion_photos(uuid,uuid), public.ff_deletion_phase(uuid,uuid,text),
  public.ff_deletion_failed(uuid,uuid,text), public.ff_finish_deletion(uuid,uuid), public.ff_deletion_status(text) to service_role;
commit;
