-- Disposable Dev fixture only. Run in Safari session A; keep session B separate.
begin;
do $$
declare actor_id uuid; session_id uuid; workspace uuid; device uuid; generation bigint;
 work_row ff_private.records%rowtype; batch jsonb; receipt jsonb;
begin
 select id into actor_id from auth.users where email='ff-history-concurrency-owner@example.invalid';
 select id into session_id from auth.sessions where user_id=actor_id limit 1;
 select id,invoicing_device_id,invoicing_generation into workspace,device,generation
  from ff_private.workspaces where owner_id=actor_id;
 if workspace is null or session_id is null then raise exception 'Missing disposable fixture'; end if;
 select r.* into work_row from ff_private.records r join ff_private.records s
  on s.workspace_id=r.workspace_id and s.id=(r.fields->>'service')::uuid
  where r.workspace_id=workspace and r.kind='workItem' and r.fields is not null
   and s.fields->>'name'='Concurrency Hold Service';
 if work_row.id is null or work_row.fields->>'billingHoldID' is not null then
  raise exception 'Race work already held or absent';
 end if;
 batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,
  'deviceID',device,'invoicingGeneration',generation,'mutations',jsonb_build_array(
   jsonb_build_object('id',work_row.id,'kind','workItem','expectedRevision',work_row.revision,
    'record',jsonb_build_object('id',work_row.id,'kind','workItem','fields',
     work_row.fields||jsonb_build_object('billingHoldID',gen_random_uuid()::text)))));
 perform 1 from ff_private.workspaces where id=workspace for update;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor_id,
  'role','authenticated','session_id',session_id)::text,true);
 set local role authenticated;
 perform pg_sleep(30);
 receipt:=public.ff_sync_push_v2(batch);
 raise notice 'Hold committed at revision %',receipt->>'revision';
end $$;
commit;
select 'PASS: session A hold committed' as result;
