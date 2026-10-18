-- FarrierFlow Dev only, after separate approval and Edge-function deployment.
-- The operator privately creates ff_deletion_worker_key in Vault first, using
-- the same value as the Edge-function FF_DELETION_WORKER_KEY secret. The public
-- Dev publishable key is stored as ff_deletion_publishable_key. No secret value
-- belongs in this source or the SQL editor's saved query text.
begin;
do $$ begin
  if exists(select 1 from ff_private.deletion_jobs) then
    raise exception 'Review existing deletion jobs before installing retry schedule' using errcode='55000';
  end if;
end $$;
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
-- Hosted pg_net grants are platform-managed and cannot be revoked here.
-- Keep net out of Data API schemas; all direct database logins must be trusted
-- with the worker credential while its request is queued.

create function ff_private.dispatch_deletion_retry() returns bigint
language plpgsql security definer set search_path='' as $$
declare worker_key text; public_key text;
begin
  -- Avoid idle Edge-function invocations; offline phones do not own retries.
  if not exists(select 1 from ff_private.deletion_jobs where state in ('pending','running')
    and (lease_until is null or lease_until<=clock_timestamp())) then return null; end if;
  select decrypted_secret into worker_key from vault.decrypted_secrets where name='ff_deletion_worker_key';
  select decrypted_secret into public_key from vault.decrypted_secrets where name='ff_deletion_publishable_key';
  if worker_key is null or worker_key!~'^[A-Za-z0-9_-]{43}$'
    or public_key is null or public_key not like 'sb_publishable_%' then
    raise exception 'Deletion retry credentials unavailable' using errcode='55000';
  end if;
  return net.http_post(
    url:='https://xufledziawaapvrifbfv.supabase.co/functions/v1/delete-cloud-account/run',
    headers:=jsonb_build_object('Content-Type','application/json','apikey',public_key,
      'Authorization','Bearer '||worker_key),
    body:='{}'::jsonb, timeout_milliseconds:=120000);
end $$;
revoke all on function ff_private.dispatch_deletion_retry() from public,anon,authenticated,service_role;

do $$ begin
  if exists(select 1 from cron.job where jobname='farrierflow-deletion-retry') then
    raise exception 'Retry job already exists; review before replacing' using errcode='55000';
  end if;
  if not exists(select 1 from vault.secrets where name='ff_deletion_worker_key')
     or not exists(select 1 from vault.secrets where name='ff_deletion_publishable_key') then
    raise exception 'Operator must store retry credentials privately first' using errcode='55000';
  end if;
end $$;
select cron.schedule('farrierflow-deletion-retry','* * * * *',
  'select ff_private.dispatch_deletion_retry();');
commit;
