-- Dev only, after scheduler installation. Queued requests never commit.
begin;
create function pg_temp.ff_expect(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %', label; end if; end $$;
do $$ declare actor text; begin
  perform pg_temp.ff_expect(exists(select 1 from pg_extension e
    join pg_namespace n on n.oid=e.extnamespace
    where e.extname='pg_net' and n.nspname='extensions'),
    'HTTP extension placement avoids public-extension warning');
  foreach actor in array array['anon','authenticated','service_role'] loop
    perform pg_temp.ff_expect((select not rolcanlogin from pg_roles where rolname=actor),
      actor || ' cannot connect directly to platform-managed HTTP queue');
    perform pg_temp.ff_expect(not has_function_privilege(actor,'ff_private.dispatch_deletion_retry()','EXECUTE'),
      actor || ' cannot invoke dispatcher');
  end loop;
  -- Hosted net grants cannot be revoked. Verify its Data API exclusion through
  -- an HTTP Accept-Profile: net probe separately; SQL grants cannot prove that.
  perform pg_temp.ff_expect((select count(*)=1 from cron.job
    where jobname='farrierflow-deletion-retry' and active and schedule='* * * * *'
      and command='select ff_private.dispatch_deletion_retry();' and username='postgres'),
    'one active operator-owned minute job');
  perform pg_temp.ff_expect(not exists(select 1 from ff_private.deletion_jobs),
    'refuse existing deletion jobs');
end $$;
create temporary table ff_schedule_fixture as select gen_random_uuid() workspace_id,
  gen_random_uuid() owner_id, gen_random_uuid() job_id;
do $$ declare baseline bigint; request_id bigint; second_request bigint; f record; begin
  select count(*) into baseline from net.http_request_queue;
  perform pg_temp.ff_expect(ff_private.dispatch_deletion_retry() is null, 'idle skips HTTP');
  perform pg_temp.ff_expect((select count(*)=baseline from net.http_request_queue), 'idle queue unchanged');
  select * into f from ff_schedule_fixture;
  insert into ff_private.workspaces(id,owner_id,deleting) values(f.workspace_id,f.owner_id,true);
  insert into ff_private.deletion_jobs(id,workspace_id,user_id,receipt_hash,state,lease_id,lease_until)
    values(f.job_id,f.workspace_id,f.owner_id,repeat('c',64),'running',gen_random_uuid(),now()+interval '1 hour');
  perform pg_temp.ff_expect(ff_private.dispatch_deletion_retry() is null, 'live lease skips HTTP');
  update ff_private.deletion_jobs set state='pending',lease_id=null,lease_until=null where id=f.job_id;
  request_id:=ff_private.dispatch_deletion_retry();
  perform pg_temp.ff_expect(request_id is not null, 'pending deletion queues retry');
  perform pg_temp.ff_expect(exists(select 1 from net.http_request_queue
    where id=request_id and method='POST'
      and url='https://xufledziawaapvrifbfv.supabase.co/functions/v1/delete-cloud-account/run'
      and convert_from(body,'UTF8')='{}' and timeout_milliseconds=120000
      and headers->>'Content-Type'='application/json'
      and headers->>'Authorization'='Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='ff_deletion_worker_key')
      and headers->>'apikey'=(select decrypted_secret from vault.decrypted_secrets where name='ff_deletion_publishable_key')),
    'retry sends exact route, empty body and Vault authorization');
  update ff_private.deletion_jobs set state='running',lease_id=gen_random_uuid(),lease_until=now()-interval '1 minute'
    where id=f.job_id;
  second_request:=ff_private.dispatch_deletion_retry();
  perform pg_temp.ff_expect(second_request is not null and second_request<>request_id, 'expired lease queues retry');
  update ff_private.deletion_jobs set state='complete' where id=f.job_id;
  perform pg_temp.ff_expect(ff_private.dispatch_deletion_retry() is null, 'completed deletion skips HTTP');
end $$;
rollback;
select 'PASS: scheduler access, idle, lease and dispatch; fixtures and HTTP requests rolled back' as result;
