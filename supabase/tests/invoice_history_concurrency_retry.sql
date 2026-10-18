-- Dev only: prepare another unheld exact WorkItem after the first hold committed.
begin;
do $$
declare actor_id uuid; session_id uuid; workspace uuid; device uuid; generation bigint;
 work_row ff_private.records%rowtype; service_row ff_private.records%rowtype;
 new_service uuid:=gen_random_uuid(); new_work uuid:=gen_random_uuid(); batch jsonb;
begin
 select id into actor_id from auth.users where email='ff-history-concurrency-owner@example.invalid';
 select id into session_id from auth.sessions where user_id=actor_id limit 1;
 select id,invoicing_device_id,invoicing_generation into workspace,device,generation
  from ff_private.workspaces where owner_id=actor_id;
 select * into service_row from ff_private.records where workspace_id=workspace and kind='service'
  and fields->>'name'='Concurrency Hold Service';
 select * into work_row from ff_private.records where workspace_id=workspace and kind='workItem'
  and fields->>'service'=service_row.id::text;
 if work_row.fields->>'billingHoldID' is null then raise exception 'Previous hold not committed'; end if;
 batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,
  'deviceID',device,'invoicingGeneration',generation,'mutations',jsonb_build_array(
   jsonb_build_object('id',service_row.id,'kind','service','expectedRevision',service_row.revision,
    'record',jsonb_build_object('id',service_row.id,'kind','service','fields',
     service_row.fields||jsonb_build_object('name','Completed Concurrency Hold Service'))),
   jsonb_build_object('id',new_service,'kind','service','expectedRevision',0,
    'record',jsonb_build_object('id',new_service,'kind','service','fields',service_row.fields)),
   jsonb_build_object('id',new_work,'kind','workItem','expectedRevision',0,
    'record',jsonb_build_object('id',new_work,'kind','workItem','fields',
     (work_row.fields-'billingHoldID')||jsonb_build_object('service',new_service::text)))));
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor_id,
  'role','authenticated','session_id',session_id)::text,true);
 set local role authenticated;
 perform public.ff_sync_push_v2(batch);
end $$;
commit;
select 'PASS: next disposable race work prepared' as result;
