-- Self-contained hosted RPC validation with synthetic identities; always rolled back.
-- No DDL, production records, Storage objects or external Apple calls.
begin;
do $$
declare owner_id uuid := gen_random_uuid(); session_id uuid := gen_random_uuid();
        device uuid := gen_random_uuid(); workspace uuid; ids jsonb;
        batch jsonb; receipt jsonb; mutations jsonb := '[]'; record jsonb;
        fields jsonb; latest jsonb; before_invoice jsonb; before_payment jsonb;
        removed_kind text; second_device uuid := gen_random_uuid();
        before_work jsonb; before_visit jsonb; before_photo jsonb; pulled jsonb;
begin
  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at)
    values(owner_id,'authenticated','authenticated',owner_id::text||'@ff-deletion.invalid',now(),now(),now());
  insert into auth.sessions(id,user_id,created_at,updated_at) values(session_id,owner_id,now(),now());
  perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated','session_id',session_id)::text,true);
  execute 'set local role authenticated';
  workspace := (public.ff_sync_bootstrap_v2(device)->>'workspaceID')::uuid;
  select jsonb_object_agg(label,gen_random_uuid()) into ids from unnest(array[
    'businessProfile','client','barn','movedBarn','service','horse','appointment','appointmentHorse',
    'visit','visitHorse','photograph','workItem','invoice','invoiceVisit','invoiceLineItem','payment']) labels(label);
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', workspace,
    'deviceID', device, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', (ids->>'businessProfile')::uuid, 'kind', 'businessProfile', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'businessProfile')::uuid, 'kind', 'businessProfile', 'fields', jsonb_build_object('name', 'Test Business', 'phone', null, 'email', null, 'address', null, 'defaultInvoiceNote', null, 'defaultAppointmentDurationMinutes', null, 'defaultInvoiceDueDays', 14, 'nextInvoiceNumber', 2, 'currencyCode', 'GBP'))),
      jsonb_build_object('id', (ids->>'client')::uuid, 'kind', 'client', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'client')::uuid, 'kind', 'client', 'fields', jsonb_build_object('name', 'Pat', 'phone', null, 'email', null, 'notes', null))),
      jsonb_build_object('id', (ids->>'barn')::uuid, 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'barn')::uuid, 'kind', 'barn', 'fields', jsonb_build_object('name', 'Old Stable', 'address', '1 Stable Lane', 'contactNotes', null))),
      jsonb_build_object('id', (ids->>'movedBarn')::uuid, 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'movedBarn')::uuid, 'kind', 'barn', 'fields', jsonb_build_object('name', 'New Stable', 'address', null, 'contactNotes', null))),
      jsonb_build_object('id', (ids->>'service')::uuid, 'kind', 'service', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'service')::uuid, 'kind', 'service', 'fields', jsonb_build_object('name', 'Front Shoes', 'defaultAmountMinorUnits', 12500, 'currencyCode', 'GBP', 'isArchived', false))),
      jsonb_build_object('id', (ids->>'horse')::uuid, 'kind', 'horse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'horse')::uuid, 'kind', 'horse', 'fields', jsonb_build_object('name', 'Milo', 'safetyNotes', null, 'appointmentIntervalWeeks', 6, 'client', (ids->>'client')::uuid::text, 'currentBarn', (ids->>'movedBarn')::uuid::text, 'defaultService', (ids->>'service')::uuid::text))),
      jsonb_build_object('id', (ids->>'appointment')::uuid, 'kind', 'appointment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'appointment')::uuid, 'kind', 'appointment', 'fields', jsonb_build_object('startDate', '123.0', 'notes', null, 'expectedDurationMinutes', null, 'barn', (ids->>'barn')::uuid::text))),
      jsonb_build_object('id', (ids->>'appointmentHorse')::uuid, 'kind', 'appointmentHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'appointmentHorse')::uuid, 'kind', 'appointmentHorse', 'fields', jsonb_build_object('appointment', (ids->>'appointment')::uuid::text, 'horse', (ids->>'horse')::uuid::text))),
      jsonb_build_object('id', (ids->>'visit')::uuid, 'kind', 'visit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'visit')::uuid, 'kind', 'visit', 'fields', jsonb_build_object('startedAt', '123.0', 'completedAt', '133.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'appointment', (ids->>'appointment')::uuid::text, 'barn', (ids->>'barn')::uuid::text))),
      jsonb_build_object('id', (ids->>'visitHorse')::uuid, 'kind', 'visitHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'visitHorse')::uuid, 'kind', 'visitHorse', 'fields', jsonb_build_object('outcomeRawValue', 'serviced', 'workNotes', 'Front shoes', 'visit', (ids->>'visit')::uuid::text, 'horse', (ids->>'horse')::uuid::text))),
      jsonb_build_object('id', (ids->>'photograph')::uuid, 'kind', 'photograph', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'photograph')::uuid, 'kind', 'photograph', 'fields', jsonb_build_object('createdAt', '123.0', 'pixelWidth', 1200, 'pixelHeight', 900, 'byteCount', 42, 'visitHorse', (ids->>'visitHorse')::uuid::text))),
      jsonb_build_object('id', (ids->>'workItem')::uuid, 'kind', 'workItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'workItem')::uuid, 'kind', 'workItem', 'fields', jsonb_build_object('serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'service', (ids->>'service')::uuid::text, 'visitHorse', (ids->>'visitHorse')::uuid::text))),
      jsonb_build_object('id', (ids->>'invoice')::uuid, 'kind', 'invoice', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'invoice')::uuid, 'kind', 'invoice', 'fields', jsonb_build_object('number', 1, 'invoiceDate', '500.0', 'dueDate', '600.0', 'note', 'Thank you.', 'statusRawValue', 'paid', 'clientNameSnapshot', 'Pat', 'clientPhoneSnapshot', null, 'clientEmailSnapshot', null, 'businessNameSnapshot', 'Test Business', 'businessPhoneSnapshot', null, 'businessEmailSnapshot', null, 'businessAddressSnapshot', null, 'currencyCode', 'GBP', 'client', (ids->>'client')::uuid::text))),
      jsonb_build_object('id', (ids->>'invoiceVisit')::uuid, 'kind', 'invoiceVisit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'invoiceVisit')::uuid, 'kind', 'invoiceVisit', 'fields', jsonb_build_object('visitDateSnapshot', '123.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'invoice', (ids->>'invoice')::uuid::text, 'sourceVisit', (ids->>'visit')::uuid::text))),
      jsonb_build_object('id', (ids->>'invoiceLineItem')::uuid, 'kind', 'invoiceLineItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'invoiceLineItem')::uuid, 'kind', 'invoiceLineItem', 'fields', jsonb_build_object('horseNameSnapshot', 'Milo', 'serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'invoiceVisit', (ids->>'invoiceVisit')::uuid::text, 'sourceWorkItem', (ids->>'workItem')::uuid::text))),
      jsonb_build_object('id', (ids->>'payment')::uuid, 'kind', 'payment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (ids->>'payment')::uuid, 'kind', 'payment', 'fields', jsonb_build_object('amountMinorUnits', 12500, 'currencyCode', 'GBP', 'receivedAt', '700.0', 'methodRawValue', 'cheque', 'sourceRawValue', 'manual', 'otherDescription', null, 'reference', 'CHEQUE-1', 'note', null, 'invoice', (ids->>'invoice')::uuid::text)))
    ));

  receipt := public.ff_sync_push_v3(batch);
  if (receipt->>'revision')::int <> 1 then raise exception 'FAIL: initial graph'; end if;
  if public.ff_sync_push_v3(batch) <> receipt then raise exception 'FAIL: exact retry'; end if;
  for record in select value->'record' from jsonb_array_elements(batch->'mutations') loop
    fields := record->'fields'; removed_kind := record->>'kind';
    if removed_kind='invoice' then before_invoice:=fields; continue;
    elsif removed_kind='payment' then before_payment:=fields; continue;
    elsif removed_kind='workItem' then before_work:=fields; continue;
    elsif removed_kind='photograph' then before_photo:=fields; continue;
    elsif removed_kind='visit' then before_visit:=fields; fields:=jsonb_set(fields,'{appointment}','null');
    elsif removed_kind in ('appointment','appointmentHorse') then fields:=null;
    else continue; end if;
    mutations:=mutations||jsonb_build_array(jsonb_build_object('id',record->>'id','kind',removed_kind,'expectedRevision',1,
      'record',case when fields is null then null else jsonb_set(record,'{fields}',fields) end));
  end loop;
  batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,'deviceID',device,
    'invoicingGeneration',1,'mutations',mutations);
  receipt:=public.ff_sync_push_v3(batch);
  if (receipt->>'revision')::int<>2 then raise exception 'FAIL: schedule deletion'; end if;
  if public.ff_sync_push_v3(batch)<>receipt then raise exception 'FAIL: exact retry'; end if;
  if (public.ff_sync_bootstrap_v2(second_device)->>'workspaceID')::uuid<>workspace then
    raise exception 'FAIL: second client workspace'; end if;
  latest:=public.ff_sync_pull_v3(workspace,0,50);
  select jsonb_object_agg(final_records.id,final_records.record) into pulled from (
    select distinct on (m->>'id') m->>'id' id,m->'record' record
    from jsonb_array_elements(latest->'transactions') t,jsonb_array_elements(t->'mutations') m
    order by m->>'id',(t->>'revision')::bigint desc
  ) final_records;
  if pulled->(ids->>'appointment')<>'null'::jsonb or pulled->(ids->>'appointmentHorse')<>'null'::jsonb then
    raise exception 'FAIL: schedule not removed'; end if;
  if pulled->(ids->>'visit')->'fields' is distinct from jsonb_set(before_visit,'{appointment}','null') then
    raise exception 'FAIL: recorded visit changed'; end if;
  if pulled->(ids->>'workItem')->'fields' is distinct from before_work then raise exception 'FAIL: work changed'; end if;
  if pulled->(ids->>'photograph')->'fields' is distinct from before_photo then raise exception 'FAIL: photo changed'; end if;
  if pulled->(ids->>'invoice')->'fields' is distinct from before_invoice then raise exception 'FAIL: invoice changed'; end if;
  if pulled->(ids->>'payment')->'fields' is distinct from before_payment then raise exception 'FAIL: payment changed'; end if;
  -- A separate, explicit Recorded Work deletion can remove the historical aggregate.
  mutations:='[]';
  for record in select value from jsonb_each(pulled) where value<>'null'::jsonb loop
    fields:=record->'fields';removed_kind:=record->>'kind';
    if removed_kind in ('visit','visitHorse','workItem','photograph') then fields:=null;
    elsif removed_kind='invoiceVisit' then fields:=jsonb_set(fields,'{sourceVisit}','null');
    elsif removed_kind='invoiceLineItem' then fields:=jsonb_set(fields,'{sourceWorkItem}','null');
    else continue; end if;
    mutations:=mutations||jsonb_build_array(jsonb_build_object('id',record->>'id','kind',removed_kind,
      'expectedRevision',case when removed_kind='visit' then 2 else 1 end,
      'record',case when fields is null then null else jsonb_set(record,'{fields}',fields) end));
  end loop;
  batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,'deviceID',device,
    'invoicingGeneration',1,'mutations',mutations);
  receipt:=public.ff_sync_push_v3(batch);
  if (receipt->>'revision')::int<>3 then raise exception 'FAIL: explicit work deletion'; end if;
  latest:=public.ff_sync_pull_v3(workspace,2,50);
  if not exists(select 1 from jsonb_array_elements(latest->'transactions'->0->'mutations') m
    where m->>'kind'='workItem' and m->'record'='null'::jsonb) then raise exception 'FAIL: work not removed'; end if;
  if has_function_privilege('anon','public.ff_sync_push_v3(jsonb)','execute') or
     has_table_privilege('authenticated','ff_private.records','insert,update,delete') then
    raise exception 'FAIL: access controls'; end if;
  execute 'reset role';
end $$;
select 'PASS: hosted schedule deletion preserves recorded work, photos, invoice and payment across clients; only explicit work deletion removes work' as result;
rollback;
