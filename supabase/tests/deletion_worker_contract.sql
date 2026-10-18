-- FarrierFlow Dev only. This exercises SQL authorization and durable phase
-- transitions with synthetic metadata, not real Storage bytes or Apple tokens.
begin;
create function pg_temp.ff_expect(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %', label; end if; end $$;
select pg_temp.ff_expect(to_regprocedure('public.ff_claim_deletions(integer)') is not null, 'worker installed');
select pg_temp.ff_expect(not has_function_privilege('anon','public.ff_deletion_owner(uuid)','execute'), 'anonymous owner denied');
select pg_temp.ff_expect(not has_function_privilege('authenticated','public.ff_queue_deletion(uuid,uuid,uuid,uuid,text,jsonb)','execute'), 'client cannot queue without verified server proof');
select pg_temp.ff_expect(not has_function_privilege('authenticated','public.ff_claim_deletions(integer)','execute'), 'client cannot claim jobs');
select pg_temp.ff_expect(not has_function_privilege('anon','public.ff_deletion_status(text)','execute'), 'direct anonymous receipt lookup denied');
select pg_temp.ff_expect(not has_table_privilege('service_role','ff_private.deletion_receipts','select,insert,update,delete'), 'receipt table has no direct service grants');
select pg_temp.ff_expect(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='ff_private' and c.relkind='r' and not c.relrowsecurity), 'private tables have RLS');

create temporary table ff_deletion_fixture as select gen_random_uuid() account_id,
  gen_random_uuid() other_id, gen_random_uuid() session_id, gen_random_uuid() device_id,
  gen_random_uuid() job_id, null::uuid workspace_id, null::uuid lease_id,
  repeat('a',64) receipt_hash, null::text photo_path;
grant select,update on ff_deletion_fixture to authenticated,service_role;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at)
select account_id,'authenticated','authenticated',account_id::text||'@example.invalid',now(),now(),now() from ff_deletion_fixture
union all select other_id,'authenticated','authenticated',other_id::text||'@example.invalid',now(),now(),now() from ff_deletion_fixture;
insert into auth.sessions(id,user_id,created_at,updated_at)
select session_id,account_id,now(),now() from ff_deletion_fixture;
select set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated','session_id',session_id)::text,true) from ff_deletion_fixture;
set local role authenticated;
update ff_deletion_fixture set workspace_id=(public.ff_sync_bootstrap(device_id)->>'workspaceID')::uuid;
do $$ declare f record; begin
  select * into f from ff_deletion_fixture;
  begin perform public.ff_deletion_owner(f.workspace_id); raise exception 'FAIL: non-Apple owner accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.ff_request_cloud_deletion(f.workspace_id); raise exception 'FAIL: unverified legacy deletion accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into auth.identities(id,user_id,provider_id,provider,identity_data,created_at,updated_at)
select gen_random_uuid(),account_id,'synthetic-apple-subject','apple',
  jsonb_build_object('sub','synthetic-apple-subject'),now(),now() from ff_deletion_fixture;
set local role authenticated;
do $$ declare f record; proof jsonb; begin
  select * into f from ff_deletion_fixture;
  proof:=public.ff_deletion_owner(f.workspace_id);
  perform pg_temp.ff_expect(proof->>'accountID'=f.account_id::text and proof->>'sessionID'=f.session_id::text
    and proof->>'appleSubject'='synthetic-apple-subject', 'owner proof bound to immutable Apple identity and live session');
end $$;
reset role;
-- Metadata only: fake object presence must block completion. No JPEG is stored.
update ff_deletion_fixture set photo_path=workspace_id::text||'/'||gen_random_uuid()::text||'.jpg';
insert into ff_private.records(workspace_id,id,kind,fields,revision)
select workspace_id,gen_random_uuid(),'client',jsonb_build_object('name','Synthetic Deletion Client','phone',null,'email',null,'notes',null),1 from ff_deletion_fixture;
insert into ff_private.commits(workspace_id,revision,operation_id,request_hash,mutations)
select workspace_id,1,gen_random_uuid(),'synthetic','[]'::jsonb from ff_deletion_fixture;
set local role service_role;
do $$ declare f record; sealed jsonb:=jsonb_build_object('version',1,'iv',repeat('a',16),'ciphertext',repeat('b',32)); result jsonb; begin
  select * into f from ff_deletion_fixture;
  begin perform public.ff_queue_deletion(f.other_id,f.session_id,f.workspace_id,f.job_id,f.receipt_hash,sealed);
    raise exception 'FAIL: wrong owner queued'; exception when insufficient_privilege then null; end;
  begin perform public.ff_queue_deletion(f.account_id,gen_random_uuid(),f.workspace_id,f.job_id,f.receipt_hash,sealed);
    raise exception 'FAIL: revoked session queued'; exception when insufficient_privilege then null; end;
  result:=public.ff_queue_deletion(f.account_id,f.session_id,f.workspace_id,f.job_id,f.receipt_hash,sealed);
  perform pg_temp.ff_expect(result->>'state'='pending' and result->>'jobID'=f.job_id::text, 'verified service request queues');
  perform pg_temp.ff_expect(public.ff_queue_deletion(f.account_id,f.session_id,f.workspace_id,f.job_id,f.receipt_hash,sealed)=result, 'same request idempotent');
  perform pg_temp.ff_expect(public.ff_deletion_status(f.receipt_hash)->>'state'='pending','durable receipt pending');
end $$;
reset role;
set local role authenticated;
do $$ declare f record; begin
  select * into f from ff_deletion_fixture;
  begin perform public.ff_sync_pull(f.workspace_id,0,1); raise exception 'FAIL: deleting workspace readable';
  exception when insufficient_privilege then null; end;
  begin perform public.ff_sync_bootstrap(f.device_id); raise exception 'FAIL: deleting workspace recreated';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role service_role;
do $$ declare f record; jobs jsonb; begin
  select * into f from ff_deletion_fixture;
  jobs:=public.ff_claim_deletions(1);
  perform pg_temp.ff_expect(jsonb_array_length(jobs)=1 and jobs->0->>'jobID'=f.job_id::text,'job leased');
  update ff_deletion_fixture set lease_id=(jobs->0->>'leaseID')::uuid;
  perform pg_temp.ff_expect(public.ff_claim_deletions(1)='[]'::jsonb,'active lease not claimed twice');
  select * into f from ff_deletion_fixture;
  begin perform public.ff_deletion_phase(f.job_id,f.lease_id,'records'); raise exception 'FAIL: records removed before photos';
  exception when check_violation then null; end;
  begin perform public.ff_deletion_phase(f.job_id,gen_random_uuid(),'photos'); raise exception 'FAIL: wrong lease accepted';
  exception when object_not_in_prerequisite_state then null; end;
end $$;
reset role;
-- Roll back only the temporary presence fixture, rather than bypassing the
-- platform's storage.protect_delete() trigger or deleting Storage metadata.
savepoint synthetic_photo_presence;
insert into storage.objects(bucket_id,name) select 'farrierflow-photos',photo_path from ff_deletion_fixture;
set local role service_role;
do $$ declare f record; begin
  select * into f from ff_deletion_fixture;
  begin perform public.ff_deletion_phase(f.job_id,f.lease_id,'photos'); raise exception 'FAIL: surviving photo marked removed';
  exception when check_violation then null; end;
  perform pg_temp.ff_expect(public.ff_deletion_photos(f.job_id,f.lease_id)=jsonb_build_array(f.photo_path),'only leased workspace paths returned');
end $$;
reset role;
rollback to savepoint synthetic_photo_presence;
release savepoint synthetic_photo_presence;
set local role service_role;
select public.ff_deletion_phase(job_id,lease_id,'photos') from ff_deletion_fixture;
select public.ff_deletion_phase(job_id,lease_id,'records') from ff_deletion_fixture;
do $$ declare f record; begin
  select * into f from ff_deletion_fixture;
  begin perform public.ff_finish_deletion(f.job_id,f.lease_id); raise exception 'FAIL: finished before Apple/Auth';
  exception when check_violation then null; end;
  perform public.ff_deletion_phase(f.job_id,f.lease_id,'apple');
  begin perform public.ff_finish_deletion(f.job_id,f.lease_id); raise exception 'FAIL: finished while Auth exists';
  exception when check_violation then null; end;
  perform public.ff_deletion_failed(f.job_id,f.lease_id,'cleanup_unconfirmed');
  perform pg_temp.ff_expect(public.ff_deletion_status(f.receipt_hash)->>'state'='pending','failure remains pending');
  update ff_deletion_fixture set lease_id=(public.ff_claim_deletions(1)->0->>'leaseID')::uuid;
end $$;
reset role;
select pg_temp.ff_expect(not exists(select 1 from ff_private.records where workspace_id=(select workspace_id from ff_deletion_fixture))
  and not exists(select 1 from ff_private.commits where workspace_id=(select workspace_id from ff_deletion_fixture)), 'records and commits removed');
select pg_temp.ff_expect(exists(select 1 from ff_private.deletion_jobs where id=(select job_id from ff_deletion_fixture)
  and photos_removed and records_removed and apple_revoked and encrypted_apple_token is null),'durable phases survive retry and encrypted token cleared');
delete from auth.users where id=(select account_id from ff_deletion_fixture);
set local role service_role;
select public.ff_finish_deletion(job_id,lease_id) from ff_deletion_fixture;
select pg_temp.ff_expect(public.ff_deletion_status(receipt_hash)=jsonb_build_object('state','complete','jobID',job_id), 'unlinked receipt confirms completed deletion') from ff_deletion_fixture;
reset role;
select pg_temp.ff_expect(not exists(select 1 from ff_private.workspaces where id=(select workspace_id from ff_deletion_fixture))
  and not exists(select 1 from ff_private.deletion_jobs where id=(select job_id from ff_deletion_fixture)),'workspace and job removed');
select pg_temp.ff_expect(not exists(select 1 from auth.sessions where id=(select session_id from ff_deletion_fixture)),'Auth sessions removed');
rollback;
select 'PASS: deletion worker SQL contract; synthetic metadata rolled back' as result;
