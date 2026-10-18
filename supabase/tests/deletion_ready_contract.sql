-- Dev only: a residual synthetic Storage row must prevent Auth removal.
begin;
create temporary table ff_ready_fixture as select gen_random_uuid() job_id,
  gen_random_uuid() workspace_id, gen_random_uuid() account_id, gen_random_uuid() lease_id;
grant select on ff_ready_fixture to service_role;
insert into ff_private.workspaces(id,owner_id,deleting)
select workspace_id,account_id,true from ff_ready_fixture;
insert into ff_private.deletion_jobs(id,workspace_id,user_id,receipt_hash,state,lease_id,lease_until,
  photos_removed,records_removed,apple_revoked)
select job_id,workspace_id,account_id,repeat('c',64),'running',lease_id,clock_timestamp()+interval '2 minutes',
  true,true,true from ff_ready_fixture;
insert into storage.objects(bucket_id,name)
select 'farrierflow-photos',workspace_id::text||'/'||gen_random_uuid()::text||'.jpg' from ff_ready_fixture;
set local role service_role;
do $$ declare f record; begin
  select * into f from ff_ready_fixture;
  begin perform public.ff_deletion_phase(f.job_id,f.lease_id,'ready');
    raise exception 'FAIL: residual object allowed Auth removal';
  exception when check_violation then null; end;
end $$;
reset role;
rollback;
select 'PASS: residual photo blocks Auth removal; synthetic metadata rolled back' as result;
