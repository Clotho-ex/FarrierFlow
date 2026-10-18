-- Dev only: synthetic worker jobs roll back; no Auth, Storage bytes or Apple grants.
begin;
create function pg_temp.ff_expect(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %', label; end if; end $$;
create temporary table ff_retry_fixture as select gen_random_uuid() first_job,
  gen_random_uuid() second_job, gen_random_uuid() first_workspace,
  gen_random_uuid() second_workspace, gen_random_uuid() first_owner,
  gen_random_uuid() second_owner, null::uuid first_lease;
grant select,update on ff_retry_fixture to service_role;
insert into ff_private.workspaces(id,owner_id,deleting)
select first_workspace,first_owner,true from ff_retry_fixture
union all select second_workspace,second_owner,true from ff_retry_fixture;
insert into ff_private.deletion_jobs(id,workspace_id,user_id,receipt_hash,created_at)
select first_job,first_workspace,first_owner,repeat('a',64),now()-interval '2 hours' from ff_retry_fixture
union all select second_job,second_workspace,second_owner,repeat('b',64),now()-interval '1 hour' from ff_retry_fixture;
set local role service_role;
do $$ declare f record; jobs jsonb; begin
  select * into f from ff_retry_fixture;
  jobs:=public.ff_claim_deletions(1);
  perform pg_temp.ff_expect(jobs->0->>'jobID'=f.first_job::text,'oldest unattempted job claimed first');
  update ff_retry_fixture set first_lease=(jobs->0->>'leaseID')::uuid;
  select * into f from ff_retry_fixture;
  perform public.ff_deletion_failed(f.first_job,(jobs->0->>'leaseID')::uuid,'cleanup_unconfirmed');
  jobs:=public.ff_claim_deletions(1);
  perform pg_temp.ff_expect(jobs->0->>'jobID'=f.second_job::text,'failed oldest job cannot starve the next deletion');
  perform public.ff_deletion_failed(f.second_job,(jobs->0->>'leaseID')::uuid,'cleanup_unconfirmed');
  jobs:=public.ff_claim_deletions(1);
  perform pg_temp.ff_expect(jobs->0->>'jobID'=f.first_job::text,'least recently attempted job gets the next retry');
  perform pg_temp.ff_expect(jobs->0->>'leaseID'<>f.first_lease::text,'retry receives a new lease');
end $$;
reset role;
rollback;
select 'PASS: fair deletion retries; synthetic jobs rolled back' as result;
