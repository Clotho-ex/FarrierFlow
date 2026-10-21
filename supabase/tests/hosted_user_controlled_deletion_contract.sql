-- Self-contained hosted RPC validation with synthetic identities; always rolled back.
-- No DDL, production records, Storage objects or external Apple calls.
begin;
do $$
declare owner_id uuid := gen_random_uuid(); session_id uuid := gen_random_uuid();
        device uuid := gen_random_uuid(); workspace uuid; ids jsonb;
        batch jsonb; receipt jsonb; mutations jsonb := '[]'; record jsonb;
        fields jsonb; latest jsonb; before_invoice jsonb; before_payment jsonb;
        invoice_id uuid; removed_kind text;
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
  invoice_id := (ids->>'invoice')::uuid;
  for record in select value->'record' from jsonb_array_elements(batch->'mutations') loop
    fields := record->'fields'; removed_kind := record->>'kind';
    if removed_kind='invoice' then before_invoice:=fields; fields:=jsonb_set(fields,'{client}','null');
    elsif removed_kind='invoiceVisit' then fields:=jsonb_set(fields,'{sourceVisit}','null');
    elsif removed_kind='invoiceLineItem' then fields:=jsonb_set(fields,'{sourceWorkItem}','null');
    elsif removed_kind='payment' then before_payment:=fields; continue;
    elsif removed_kind in ('businessProfile','barn','service') then continue;
    else fields:=null; end if;
    mutations:=mutations||jsonb_build_array(jsonb_build_object('id',record->>'id','kind',removed_kind,'expectedRevision',1,
      'record',case when fields is null then null else jsonb_set(record,'{fields}',fields) end));
  end loop;
  batch := jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,'deviceID',device,
    'invoicingGeneration',1,'mutations',mutations);
  receipt := public.ff_sync_push_v3(batch);
  if (receipt->>'revision')::int <> 2 then raise exception 'FAIL: cascade'; end if;
  latest := public.ff_sync_pull_v3(workspace,0,50);
  select value->'record'->'fields' into fields
    from jsonb_array_elements(latest->'transactions'->1->'mutations') where value->>'kind'='invoice';
  if fields is distinct from jsonb_set(before_invoice,'{client}','null') then raise exception 'FAIL: saved financial values'; end if;
  select value->'record'->'fields' into fields
    from jsonb_array_elements(latest->'transactions'->0->'mutations') where value->>'kind'='payment';
  if fields is distinct from before_payment then raise exception 'FAIL: payment evidence'; end if;
  if (public.ff_sync_bootstrap_v2(device)->>'minimumProtocolVersion')::int <> 3 then raise exception 'FAIL: protocol gate'; end if;
  begin
    perform public.ff_sync_pull_v2(workspace,0,50);
    raise exception 'FAIL: legacy gate';
  exception when sqlstate 'P0001' then if sqlerrm <> 'FF_PROTOCOL_UPGRADE_REQUIRED' then raise; end if; end;
  -- Delete the independent paid invoice and its retained payment separately.
  mutations:='[]';
  for removed_kind in select unnest(array['invoice','invoiceVisit','invoiceLineItem','payment']) loop
    mutations:=mutations||jsonb_build_array(jsonb_build_object('id',ids->>removed_kind,'kind',removed_kind,
      'expectedRevision',case when removed_kind='payment' then 1 else 2 end,'record',null));
  end loop;
  batch:=jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace,'deviceID',device,
    'invoicingGeneration',1,'mutations',mutations);
  receipt:=public.ff_sync_push_v3(batch);
  if (receipt->>'revision')::int <> 3 then raise exception 'FAIL: paid invoice delete'; end if;
  if has_function_privilege('anon','public.ff_sync_push_v3(jsonb)','execute') or
    has_table_privilege('authenticated','ff_private.records','insert,update,delete') then raise exception 'FAIL: permissions'; end if;
  execute 'reset role';
end $$;
select 'PASS: hosted protocol-three cascade, paid snapshots/payment preservation, separate invoice deletion, retry and access controls' as result;
rollback;
