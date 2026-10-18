-- Approved FarrierFlow Dev relocation; refuse unsent requests or unknown data.
-- The only disposable response is the prior no-job worker probe (request 3).
begin;
lock table ff_private.deletion_jobs in share mode;
create temporary table ff_net_relocation_snapshot on commit drop as
select e.extversion, to_jsonb(j) as retry_job,
  pg_get_functiondef('ff_private.dispatch_deletion_retry()'::regprocedure) as dispatcher
from pg_extension e cross join cron.job j
where e.extname='pg_net' and j.jobname='farrierflow-deletion-retry';
do $$ begin
  if not exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
    where e.extname='pg_net' and n.nspname='public') then
    raise exception 'Expected Dev public pg_net installation' using errcode='55000';
  end if;
  if (select count(*) from ff_net_relocation_snapshot)<>1
    or not exists(select 1 from ff_net_relocation_snapshot
      where retry_job->>'active'='true' and retry_job->>'schedule'='* * * * *'
        and retry_job->>'command'='select ff_private.dispatch_deletion_retry();'
        and retry_job->>'username'='postgres') then
    raise exception 'Unexpected Dev retry job' using errcode='55000';
  end if;
  if exists(select 1 from ff_private.deletion_jobs)
    or exists(select 1 from net.http_request_queue) then
    raise exception 'Refuse relocation with deletion jobs or queued requests' using errcode='55000';
  end if;
  if exists(select 1 from net._http_response where id<>3
    or status_code is distinct from 200
    or content is distinct from '{"processed":0,"completed":0}') then
    raise exception 'Review unexpected HTTP responses before relocation' using errcode='55000';
  end if;
end $$;
-- No CASCADE: unexpected dependencies abort and roll back the relocation.
drop extension pg_net;
create extension pg_net with schema extensions;
do $$ begin
  if not exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
    where e.extname='pg_net' and n.nspname='extensions'
      and e.extversion=(select extversion from ff_net_relocation_snapshot)) then
    raise exception 'Relocation must preserve the HTTP extension version' using errcode='55000';
  end if;
  if (select to_jsonb(j) from cron.job j where j.jobname='farrierflow-deletion-retry')
      is distinct from (select retry_job from ff_net_relocation_snapshot)
    or pg_get_functiondef('ff_private.dispatch_deletion_retry()'::regprocedure)
      is distinct from (select dispatcher from ff_net_relocation_snapshot) then
    raise exception 'Relocation changed the retry job or dispatcher' using errcode='55000';
  end if;
end $$;
commit;
select 'PASS: pg_net relocated at the same version; retry job and dispatcher preserved' as result;
