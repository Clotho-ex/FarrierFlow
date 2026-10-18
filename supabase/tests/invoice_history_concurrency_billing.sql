-- Disposable Dev fixture only. Start while session A holds its workspace lock.
begin;
do $$
declare actor_id uuid; session_id uuid; workspace uuid; device uuid; generation bigint;
 work_row ff_private.records%rowtype; profile ff_private.records%rowtype;
 invoice ff_private.records%rowtype; group_row ff_private.records%rowtype;
 invoice_id uuid:=gen_random_uuid(); group_id uuid:=gen_random_uuid(); line_id uuid:=gen_random_uuid();
 batch jsonb; started timestamptz:=clock_timestamp();
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
 if work_row.fields->>'billingHoldID' is not null then raise exception 'Race started after hold'; end if;
 select * into profile from ff_private.records where workspace_id=workspace and kind='businessProfile' and fields is not null;
 select * into invoice from ff_private.records where workspace_id=workspace and kind='invoice' and fields is not null limit 1;
 select * into group_row from ff_private.records where workspace_id=workspace and kind='invoiceVisit' and fields is not null limit 1;
 batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,
  'deviceID',device,'invoicingGeneration',generation,'mutations',jsonb_build_array(
   jsonb_build_object('id',profile.id,'kind','businessProfile','expectedRevision',profile.revision,
    'record',jsonb_build_object('id',profile.id,'kind','businessProfile','fields',
     profile.fields||jsonb_build_object('nextInvoiceNumber',(profile.fields->>'nextInvoiceNumber')::bigint+1))),
   jsonb_build_object('id',invoice_id,'kind','invoice','expectedRevision',0,
    'record',jsonb_build_object('id',invoice_id,'kind','invoice','fields',
     invoice.fields||jsonb_build_object('number',(profile.fields->>'nextInvoiceNumber')::bigint,'statusRawValue','unpaid'))),
   jsonb_build_object('id',group_id,'kind','invoiceVisit','expectedRevision',0,
    'record',jsonb_build_object('id',group_id,'kind','invoiceVisit','fields',
     group_row.fields||jsonb_build_object('invoice',invoice_id::text))),
   jsonb_build_object('id',line_id,'kind','invoiceLineItem','expectedRevision',0,
    'record',jsonb_build_object('id',line_id,'kind','invoiceLineItem','fields',jsonb_build_object(
     'horseNameSnapshot','Race Horse','serviceNameSnapshot',work_row.fields->>'serviceNameSnapshot',
     'amountMinorUnits',(work_row.fields->>'amountMinorUnits')::bigint,'currencyCode',work_row.fields->>'currencyCode',
     'invoiceVisit',group_id::text,'sourceWorkItem',work_row.id::text)))));
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor_id,
  'role','authenticated','session_id',session_id)::text,true);
 set local role authenticated;
 begin
  perform public.ff_sync_push_v2(batch);
  raise exception 'FAIL: concurrent billing accepted';
 exception when raise_exception then
  if sqlerrm is distinct from 'FF_ALREADY_BILLED' then raise; end if;
 end;
 reset role;
 if clock_timestamp()-started < interval '1 second' then raise exception 'No actual lock wait observed'; end if;
 if exists(select 1 from ff_private.records where workspace_id=workspace and id in(invoice_id,group_id,line_id)) then
  raise exception 'Rejected billing left partial records';
 end if;
end $$;
rollback;
select 'PASS: session B waited for hold and billing rolled back' as result;
