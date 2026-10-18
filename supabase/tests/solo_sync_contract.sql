-- Run only against FarrierFlow Dev. All synthetic users and sessions roll back.
begin;
create function pg_temp.ff_expect(ok boolean, label text) returns void
language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAIL: %', label; end if;
end $$;

select pg_temp.ff_expect(
  to_regprocedure('public.ff_sync_push(jsonb)') is not null, 'sync push exists');
select pg_temp.ff_expect(
  to_regprocedure('public.ff_sync_pull(uuid,bigint,integer)') is not null, 'sync pull exists');
select pg_temp.ff_expect(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'ff_private' and c.relkind = 'r' and not c.relrowsecurity
  ), 'every private application table has RLS');
select pg_temp.ff_expect(
  not has_function_privilege('anon', 'public.ff_sync_push(jsonb)', 'execute'),
  'anonymous push denied');
select pg_temp.ff_expect(
  has_function_privilege('authenticated', 'public.ff_sync_push(jsonb)', 'execute'),
  'authenticated push endpoint available');
select pg_temp.ff_expect(
  not has_table_privilege('authenticated', 'ff_private.records', 'insert,update,delete'),
  'direct business writes denied');
select pg_temp.ff_expect(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'ff_%' and p.prosecdef
  ), 'exposed wrappers do not bypass authorization');
select pg_temp.ff_expect(
  exists(select 1 from storage.buckets where id = 'farrierflow-photos' and not public),
  'photograph bucket is private');

create temporary table ff_test_ids as select
  gen_random_uuid() as owner_id, gen_random_uuid() as other_id,
  gen_random_uuid() as owner_session, gen_random_uuid() as other_session,
  gen_random_uuid() as device_id, gen_random_uuid() as client_id,
  null::uuid as workspace_id;
grant select, update on ff_test_ids to authenticated;
create temporary table ff_test_graph_ids(label text primary key, id uuid not null);
insert into ff_test_graph_ids(label, id) values
  ('businessProfile', gen_random_uuid()),
  ('client', gen_random_uuid()),
  ('barn', gen_random_uuid()),
  ('movedBarn', gen_random_uuid()),
  ('service', gen_random_uuid()),
  ('horse', gen_random_uuid()),
  ('appointment', gen_random_uuid()),
  ('appointmentHorse', gen_random_uuid()),
  ('visit', gen_random_uuid()),
  ('visitHorse', gen_random_uuid()),
  ('photograph', gen_random_uuid()),
  ('workItem', gen_random_uuid()),
  ('invoice', gen_random_uuid()),
  ('invoiceVisit', gen_random_uuid()),
  ('invoiceLineItem', gen_random_uuid()),
  ('payment', gen_random_uuid());
grant select on ff_test_graph_ids to authenticated;


insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at)
select owner_id, 'authenticated', 'authenticated',
       owner_id::text || '@example.invalid', now(), now(), now() from ff_test_ids
union all
select other_id, 'authenticated', 'authenticated',
       other_id::text || '@example.invalid', now(), now(), now() from ff_test_ids;
insert into auth.sessions(id, user_id, created_at, updated_at)
select owner_session, owner_id, now(), now() from ff_test_ids
union all
select other_session, other_id, now(), now() from ff_test_ids;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', owner_id, 'role', 'authenticated', 'session_id', owner_session)::text, true)
from ff_test_ids;
set local role authenticated;
update ff_test_ids set workspace_id =
  (public.ff_sync_bootstrap(device_id)->>'workspaceID')::uuid;

do $$
declare fixture record; batch jsonb; first jsonb; replay jsonb;
begin
  select * into fixture from ff_test_ids;
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object(
      'id', fixture.client_id, 'kind', 'client', 'expectedRevision', 0,
      'record', jsonb_build_object('id', fixture.client_id, 'kind', 'client',
        'fields', jsonb_build_object('name', 'Synthetic Client', 'phone', null,
          'email', null, 'notes', null)))));
  first := public.ff_sync_push(batch);
  replay := public.ff_sync_push(batch);
  perform pg_temp.ff_expect(first = replay, 'idempotent receipt');
  perform pg_temp.ff_expect((first->>'revision')::bigint = 1, 'first commit cursor');
  perform pg_temp.ff_expect(
    jsonb_array_length(public.ff_sync_pull(fixture.workspace_id, 0, 1)->'transactions') = 1,
    'authorized pull');
  batch := jsonb_set(batch, '{operationID}', to_jsonb(gen_random_uuid()));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: stale revision accepted';
  exception when serialization_failure then null;
  end;
end $$;

do $$
declare fixture record; batch jsonb; receipt jsonb; invoice_id uuid; prior jsonb;
        visit_record jsonb;
begin
  select * into fixture from ff_test_ids;
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'businessProfile'), 'kind', 'businessProfile', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'businessProfile'), 'kind', 'businessProfile', 'fields', jsonb_build_object('name', 'Test Business', 'phone', null, 'email', null, 'address', null, 'defaultInvoiceNote', null, 'defaultAppointmentDurationMinutes', null, 'defaultInvoiceDueDays', 14, 'nextInvoiceNumber', 2, 'currencyCode', 'GBP'))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'client'), 'kind', 'client', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'client'), 'kind', 'client', 'fields', jsonb_build_object('name', 'Pat', 'phone', null, 'email', null, 'notes', null))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'barn'), 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'barn'), 'kind', 'barn', 'fields', jsonb_build_object('name', 'Old Stable', 'address', '1 Stable Lane', 'contactNotes', null))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'movedBarn'), 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'movedBarn'), 'kind', 'barn', 'fields', jsonb_build_object('name', 'New Stable', 'address', null, 'contactNotes', null))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'service'), 'kind', 'service', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'service'), 'kind', 'service', 'fields', jsonb_build_object('name', 'Front Shoes', 'defaultAmountMinorUnits', 12500, 'currencyCode', 'GBP', 'isArchived', false))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'horse'), 'kind', 'horse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'horse'), 'kind', 'horse', 'fields', jsonb_build_object('name', 'Milo', 'safetyNotes', null, 'appointmentIntervalWeeks', 6, 'client', (select id from ff_test_graph_ids where label = 'client')::text, 'currentBarn', (select id from ff_test_graph_ids where label = 'movedBarn')::text, 'defaultService', (select id from ff_test_graph_ids where label = 'service')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'appointment'), 'kind', 'appointment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'appointment'), 'kind', 'appointment', 'fields', jsonb_build_object('startDate', '123.0', 'notes', null, 'expectedDurationMinutes', null, 'barn', (select id from ff_test_graph_ids where label = 'barn')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'appointmentHorse'), 'kind', 'appointmentHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'appointmentHorse'), 'kind', 'appointmentHorse', 'fields', jsonb_build_object('appointment', (select id from ff_test_graph_ids where label = 'appointment')::text, 'horse', (select id from ff_test_graph_ids where label = 'horse')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'visit'), 'kind', 'visit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'visit'), 'kind', 'visit', 'fields', jsonb_build_object('startedAt', '123.0', 'completedAt', '133.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'appointment', (select id from ff_test_graph_ids where label = 'appointment')::text, 'barn', (select id from ff_test_graph_ids where label = 'barn')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'visitHorse'), 'kind', 'visitHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'visitHorse'), 'kind', 'visitHorse', 'fields', jsonb_build_object('outcomeRawValue', 'serviced', 'workNotes', 'Front shoes', 'visit', (select id from ff_test_graph_ids where label = 'visit')::text, 'horse', (select id from ff_test_graph_ids where label = 'horse')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'photograph'), 'kind', 'photograph', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'photograph'), 'kind', 'photograph', 'fields', jsonb_build_object('createdAt', '123.0', 'pixelWidth', 1200, 'pixelHeight', 900, 'byteCount', 42, 'visitHorse', (select id from ff_test_graph_ids where label = 'visitHorse')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'workItem'), 'kind', 'workItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'workItem'), 'kind', 'workItem', 'fields', jsonb_build_object('serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'service', (select id from ff_test_graph_ids where label = 'service')::text, 'visitHorse', (select id from ff_test_graph_ids where label = 'visitHorse')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoice'), 'kind', 'invoice', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoice'), 'kind', 'invoice', 'fields', jsonb_build_object('number', 1, 'invoiceDate', '500.0', 'dueDate', '600.0', 'note', 'Thank you.', 'statusRawValue', 'paid', 'clientNameSnapshot', 'Pat', 'clientPhoneSnapshot', null, 'clientEmailSnapshot', null, 'businessNameSnapshot', 'Test Business', 'businessPhoneSnapshot', null, 'businessEmailSnapshot', null, 'businessAddressSnapshot', null, 'currencyCode', 'GBP', 'client', (select id from ff_test_graph_ids where label = 'client')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoiceVisit'), 'kind', 'invoiceVisit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoiceVisit'), 'kind', 'invoiceVisit', 'fields', jsonb_build_object('visitDateSnapshot', '123.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'invoice', (select id from ff_test_graph_ids where label = 'invoice')::text, 'sourceVisit', (select id from ff_test_graph_ids where label = 'visit')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoiceLineItem'), 'kind', 'invoiceLineItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'invoiceLineItem'), 'kind', 'invoiceLineItem', 'fields', jsonb_build_object('horseNameSnapshot', 'Milo', 'serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'invoiceVisit', (select id from ff_test_graph_ids where label = 'invoiceVisit')::text, 'sourceWorkItem', (select id from ff_test_graph_ids where label = 'workItem')::text))),
      jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'payment'), 'kind', 'payment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_test_graph_ids where label = 'payment'), 'kind', 'payment', 'fields', jsonb_build_object('amountMinorUnits', 12500, 'currencyCode', 'GBP', 'receivedAt', '700.0', 'methodRawValue', 'cheque', 'sourceRawValue', 'manual', 'otherDescription', null, 'reference', 'CHEQUE-1', 'note', null, 'invoice', (select id from ff_test_graph_ids where label = 'invoice')::text)))
    ));
  receipt := public.ff_sync_push(batch);
  perform pg_temp.ff_expect((receipt->>'revision')::bigint = 2,
    'complete paid GBP graph with horse moved after completion is accepted');
  perform pg_temp.ff_expect(
    jsonb_array_length(public.ff_sync_pull(fixture.workspace_id, 1, 1)->'transactions'->0->'mutations') = 16,
    'all business graph identities survive hosted pull');
  select id into invoice_id from ff_test_graph_ids where label = 'invoice';
  prior := public.ff_sync_pull(fixture.workspace_id, 1, 1);
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object(
      'id', invoice_id, 'kind', 'invoice', 'expectedRevision', 2,
      'record', jsonb_build_object('id', invoice_id, 'kind', 'invoice',
        'fields', jsonb_set(jsonb_build_object('number', 1, 'invoiceDate', '500.0', 'dueDate', '600.0', 'note', 'Thank you.', 'statusRawValue', 'paid', 'clientNameSnapshot', 'Pat', 'clientPhoneSnapshot', null, 'clientEmailSnapshot', null, 'businessNameSnapshot', 'Test Business', 'businessPhoneSnapshot', null, 'businessEmailSnapshot', null, 'businessAddressSnapshot', null, 'currencyCode', 'GBP', 'client', (select id from ff_test_graph_ids where label = 'client')::text), '{number}', '99')))));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: issued invoice number overwritten';
  exception when check_violation then null;
  end;
  perform pg_temp.ff_expect(
    public.ff_sync_pull(fixture.workspace_id, 1, 1) = prior,
    'rejected invoice edit has no revision or graph side effects');
  select value->'record' into visit_record
    from jsonb_array_elements(prior->'transactions'->0->'mutations')
    where value->>'kind' = 'visit';
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object(
      'id', visit_record->>'id', 'kind', 'visit', 'expectedRevision', 2,
      'record', jsonb_set(visit_record, '{fields,completedAt}', 'null'::jsonb))));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: unfinished appointment accepted a horse in another barn';
  exception when check_violation then
    perform pg_temp.ff_expect(SQLERRM = 'Horse outside appointment location',
      'location validation still applies to unfinished visits');
  end;
  perform pg_temp.ff_expect(
    public.ff_sync_pull(fixture.workspace_id, 1, 1) = prior,
    'rejected unfinished location edit is atomic');
end $$;


do $$
declare fixture record; batch jsonb; receipt jsonb;
        appointment_id uuid := gen_random_uuid(); join_id uuid := gen_random_uuid();
        visit_id uuid := gen_random_uuid(); horse_join_id uuid := gen_random_uuid();
        work_id uuid := gen_random_uuid(); outcome_record jsonb;
begin
  select * into fixture from ff_test_ids;
  outcome_record := jsonb_build_object('id', horse_join_id, 'kind', 'visitHorse',
    'fields', jsonb_build_object('outcomeRawValue', 'pending', 'workNotes', null,
      'visit', visit_id::text,
      'horse', (select id from ff_test_graph_ids where label = 'horse')::text));
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', appointment_id, 'kind', 'appointment', 'expectedRevision', 0,
        'record', jsonb_build_object('id', appointment_id, 'kind', 'appointment',
          'fields', jsonb_build_object('startDate', '800.0', 'notes', null,
            'expectedDurationMinutes', null,
            'barn', (select id from ff_test_graph_ids where label = 'movedBarn')::text))),
      jsonb_build_object('id', join_id, 'kind', 'appointmentHorse', 'expectedRevision', 0,
        'record', jsonb_build_object('id', join_id, 'kind', 'appointmentHorse',
          'fields', jsonb_build_object('appointment', appointment_id::text,
            'horse', (select id from ff_test_graph_ids where label = 'horse')::text))),
      jsonb_build_object('id', visit_id, 'kind', 'visit', 'expectedRevision', 0,
        'record', jsonb_build_object('id', visit_id, 'kind', 'visit',
          'fields', jsonb_build_object('startedAt', '800.0', 'completedAt', null,
            'serviceLocationNameSnapshot', 'New Stable', 'serviceLocationAddressSnapshot', null,
            'appointment', appointment_id::text,
            'barn', (select id from ff_test_graph_ids where label = 'movedBarn')::text))),
      jsonb_build_object('id', horse_join_id, 'kind', 'visitHorse', 'expectedRevision', 0,
        'record', outcome_record),
      jsonb_build_object('id', work_id, 'kind', 'workItem', 'expectedRevision', 0,
        'record', jsonb_build_object('id', work_id, 'kind', 'workItem',
          'fields', jsonb_build_object('serviceNameSnapshot', 'Front Shoes',
            'amountMinorUnits', 12500, 'currencyCode', 'GBP',
            'service', (select id from ff_test_graph_ids where label = 'service')::text,
            'visitHorse', horse_join_id::text)))
    ));
  receipt := public.ff_sync_push(batch);
  perform pg_temp.ff_expect((receipt->>'revision')::bigint = 3,
    'pending visit preserves saved work before outcome is resolved');
  batch := jsonb_build_object(
    'operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object(
      'id', horse_join_id, 'kind', 'visitHorse', 'expectedRevision', 3,
      'record', jsonb_set(outcome_record, '{fields,outcomeRawValue}', '"notServiced"'))));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: not-serviced horse retained work items';
  exception when check_violation then null;
  end;
  perform pg_temp.ff_expect((public.ff_sync_pull(fixture.workspace_id, 3, 1)->>'cursor')::bigint = 3,
    'rejected not-serviced work does not advance cursor');
end $$;

do $$
declare fixture record; secondary uuid := gen_random_uuid(); info jsonb;
        batch jsonb; invoice_record jsonb; new_invoice uuid := gen_random_uuid();
        photo uuid; photo_path text;
begin
  select * into fixture from ff_test_ids;
  select id into photo from ff_test_graph_ids where label = 'photograph';
  photo_path := fixture.workspace_id::text || '/' || photo::text || '.jpg';
  perform pg_temp.ff_expect(ff_private.photo_allowed(photo_path), 'owner photo path authorized');
  perform pg_temp.ff_expect(ff_private.photo_write_allowed(photo_path), 'owner upload authorization holds workspace share lock');
  perform pg_temp.ff_expect(not ff_private.photo_allowed(photo_path, true), 'live photo cannot be deleted from Storage');
  perform pg_temp.ff_expect(not ff_private.photo_allowed('../' || photo_path), 'path traversal denied');
  perform pg_temp.ff_expect(public.ff_photo_list(fixture.workspace_id) = '[]'::jsonb,
    'metadata-only photo is not falsely verified');
  begin
    perform public.ff_photo_commit(fixture.workspace_id, photo, repeat('a', 64));
    raise exception 'FAIL: missing object reported protected';
  exception when check_violation then null;
  end;
  begin
    perform public.ff_invoicing_takeover(fixture.workspace_id, secondary, 1);
    raise exception 'FAIL: unregistered device took over invoices';
  exception when insufficient_privilege then null;
  end;
  info := public.ff_sync_bootstrap(secondary);
  perform pg_temp.ff_expect((info->>'workspaceID')::uuid = fixture.workspace_id,
    'second iPhone joins existing solo workspace');
  perform pg_temp.ff_expect((info->>'invoicingDeviceID')::uuid = fixture.device_id
    and (info->>'invoicingGeneration')::bigint = 1, 'bootstrap does not silently take over');
  select value->'record' into invoice_record
    from jsonb_array_elements(public.ff_sync_pull(fixture.workspace_id, 1, 1)->'transactions'->0->'mutations')
    where value->>'kind' = 'invoice';
  invoice_record := jsonb_set(invoice_record, '{id}', to_jsonb(new_invoice));
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', secondary, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', new_invoice, 'kind', 'invoice',
      'expectedRevision', 0, 'record', invoice_record)));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: secondary iPhone issued an invoice';
  exception when insufficient_privilege then null;
  end;
  info := public.ff_invoicing_takeover(fixture.workspace_id, secondary, 1);
  perform pg_temp.ff_expect((info->>'invoicingGeneration')::bigint = 2
    and (info->>'invoicingDeviceID')::uuid = secondary, 'explicit takeover advances authority');
  perform pg_temp.ff_expect(
    public.ff_sync_pull(fixture.workspace_id, 3, 1)->'transactions'->0->'mutations' = '[]'::jsonb,
    'takeover has a commit-ordered empty invalidation transaction');
  begin
    perform public.ff_invoicing_takeover(fixture.workspace_id, fixture.device_id, 1);
    raise exception 'FAIL: stale-generation takeover accepted';
  exception when serialization_failure then null;
  end;
  batch := jsonb_set(batch, '{deviceID}', to_jsonb(fixture.device_id));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: old invoicing phone uploaded a pending invoice after takeover';
  exception when insufficient_privilege then null;
  end;
  perform pg_temp.ff_expect((public.ff_sync_pull(fixture.workspace_id, 4, 1)->>'cursor')::bigint = 4,
    'authority rejections do not advance cursor');
end $$;

do $$
declare fixture record; batch jsonb; invoice_record jsonb;
        invoice_id uuid; payment_id uuid; group_id uuid; line_id uuid;
begin
  select * into fixture from ff_test_ids;
  select id into invoice_id from ff_test_graph_ids where label = 'invoice';
  select id into payment_id from ff_test_graph_ids where label = 'payment';
  select id into group_id from ff_test_graph_ids where label = 'invoiceVisit';
  select id into line_id from ff_test_graph_ids where label = 'invoiceLineItem';
  select value->'record' into invoice_record
    from jsonb_array_elements(public.ff_sync_pull(fixture.workspace_id, 1, 1)->'transactions'->0->'mutations')
    where value->>'kind' = 'invoice';
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', invoice_id, 'kind', 'invoice', 'expectedRevision', 2, 'record', null),
      jsonb_build_object('id', group_id, 'kind', 'invoiceVisit', 'expectedRevision', 2, 'record', null),
      jsonb_build_object('id', line_id, 'kind', 'invoiceLineItem', 'expectedRevision', 2, 'record', null),
      jsonb_build_object('id', payment_id, 'kind', 'payment', 'expectedRevision', 2, 'record', null)));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: paid history deleted without payment reversal';
  exception when check_violation then null;
  end;
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', payment_id, 'kind', 'payment', 'expectedRevision', 2, 'record', null),
      jsonb_build_object('id', invoice_id, 'kind', 'invoice', 'expectedRevision', 2,
        'record', jsonb_set(invoice_record, '{fields,statusRawValue}', '"unpaid"'))));
  perform public.ff_sync_push(batch);
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', line_id, 'kind', 'invoiceLineItem',
      'expectedRevision', 2, 'record', null)));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: partial unpaid snapshot deletion accepted';
  exception when check_violation then
    perform pg_temp.ff_expect(SQLERRM = 'Invoice snapshots require complete invoice deletion',
      'partial snapshot deletion is refused by immutable-history boundary');
  end;
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(
      jsonb_build_object('id', invoice_id, 'kind', 'invoice', 'expectedRevision', 5, 'record', null),
      jsonb_build_object('id', group_id, 'kind', 'invoiceVisit', 'expectedRevision', 2, 'record', null),
      jsonb_build_object('id', line_id, 'kind', 'invoiceLineItem', 'expectedRevision', 2, 'record', null)));
  perform pg_temp.ff_expect((public.ff_sync_push(batch)->>'revision')::bigint = 6,
    'explicit unpaid invoice deletion syncs its complete snapshot cascade');
  perform pg_temp.ff_expect(
    jsonb_array_length(public.ff_sync_pull(fixture.workspace_id, 5, 1)->'transactions'->0->'mutations') = 3,
    'unpaid deletion publishes all snapshot tombstones');
end $$;

-- This rollback-only row exercises Storage RLS, not a real uploaded JPEG.
reset role;
insert into storage.objects(bucket_id, name, metadata)
select 'farrierflow-photos', workspace_id::text || '/' ||
  (select id from ff_test_graph_ids where label = 'photograph')::text || '.jpg',
  jsonb_build_object('size', 42, 'mimetype', 'image/jpeg') from ff_test_ids;
set local role authenticated;
do $$
declare fixture record; photo uuid; path text; batch jsonb;
        absent_photo uuid := gen_random_uuid(); photo_record jsonb; receipt jsonb;
begin
  select * into fixture from ff_test_ids;
  select id into photo from ff_test_graph_ids where label = 'photograph';
  path := fixture.workspace_id::text || '/' || photo::text || '.jpg';
  perform set_config('storage.operation', 'object.get_authenticated', true);
  perform pg_temp.ff_expect(exists(select 1 from storage.objects
    where bucket_id = 'farrierflow-photos' and name = path), 'owner can read live object metadata');
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', photo, 'kind', 'photograph',
      'expectedRevision', 2, 'record', null)));
  perform public.ff_sync_push(batch);
  perform pg_temp.ff_expect(not exists(select 1 from storage.objects
    where bucket_id = 'farrierflow-photos' and name = path), 'tombstoned photo cannot be downloaded');
  perform set_config('storage.operation', 'object.delete_many', true);
  perform pg_temp.ff_expect(exists(select 1 from storage.objects
    where bucket_id = 'farrierflow-photos' and name = path),
    'owner delete operation can locate only its tombstoned object');
  begin
    perform public.ff_photo_delete_confirm(fixture.workspace_id, photo);
    raise exception 'FAIL: surviving object reported deleted';
  exception when check_violation then null;
  end;
  select value->'record' into photo_record
    from jsonb_array_elements(public.ff_sync_pull(fixture.workspace_id, 1, 1)->'transactions'->0->'mutations')
    where value->>'kind' = 'photograph';
  photo_record := jsonb_set(photo_record, '{id}', to_jsonb(absent_photo));
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', absent_photo, 'kind', 'photograph',
      'expectedRevision', 0, 'record', photo_record)));
  perform public.ff_sync_push(batch);
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', fixture.workspace_id,
    'deviceID', fixture.device_id, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', absent_photo, 'kind', 'photograph',
      'expectedRevision', 8, 'record', null)));
  perform public.ff_sync_push(batch);
  receipt := public.ff_photo_delete_confirm(fixture.workspace_id, absent_photo);
  perform pg_temp.ff_expect((receipt->>'id')::uuid = absent_photo
    and receipt->'deleted' = 'true'::jsonb, 'absent tombstoned object deletion is confirmed');
  perform pg_temp.ff_expect(public.ff_photo_delete_confirm(fixture.workspace_id, absent_photo) = receipt,
    'photo cleanup confirmation is idempotent');
end $$;

reset role;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', other_id, 'role', 'authenticated', 'session_id', other_session)::text, true)
from ff_test_ids;
set local role authenticated;
do $$
declare workspace uuid; own_workspace uuid; own_device uuid := gen_random_uuid();
        fixture record; deletion jsonb; horse_id uuid := gen_random_uuid(); batch jsonb;
begin
  select * into fixture from ff_test_ids;
  workspace := fixture.workspace_id;
  begin
    perform public.ff_sync_pull(workspace, 0, 10);
    raise exception 'FAIL: another owner read a workspace';
  exception when insufficient_privilege then null;
  end;
  perform pg_temp.ff_expect(not ff_private.photo_allowed(workspace::text || '/' ||
    (select id from ff_test_graph_ids where label = 'photograph')::text || '.jpg'),
    'another owner cannot access photo bytes');
  begin
    perform public.ff_photo_list(workspace);
    raise exception 'FAIL: another owner read photo manifest';
  exception when insufficient_privilege then null;
  end;
  own_workspace := (public.ff_sync_bootstrap(own_device)->>'workspaceID')::uuid;
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', own_workspace,
    'deviceID', own_device, 'invoicingGeneration', 1,
    'mutations', jsonb_build_array(jsonb_build_object('id', horse_id, 'kind', 'horse',
      'expectedRevision', 0, 'record', jsonb_build_object('id', horse_id, 'kind', 'horse',
        'fields', jsonb_build_object('name', 'Forged Cross-Workspace Horse', 'safetyNotes', null,
          'appointmentIntervalWeeks', 6, 'defaultService', null,
          'client', (select id from ff_test_graph_ids where label = 'client')::text,
          'currentBarn', (select id from ff_test_graph_ids where label = 'barn')::text)))));
  begin
    perform public.ff_sync_push(batch);
    raise exception 'FAIL: cross-workspace relationships accepted';
  exception when foreign_key_violation then null;
  end;
  perform pg_temp.ff_expect((public.ff_sync_pull(own_workspace, 0, 1)->>'cursor')::bigint = 0,
    'cross-workspace failure leaves new workspace empty');
  begin
    perform public.ff_request_cloud_deletion(own_workspace);
    raise exception 'FAIL: deletion accepted without server-verified fresh Apple proof';
  exception when insufficient_privilege then null;
  end;
  perform pg_temp.ff_expect(ff_private.can_access(own_workspace),
    'denied legacy deletion leaves the business accessible');
end $$;

reset role;
delete from auth.sessions where id = (select owner_session from ff_test_ids);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', owner_id, 'role', 'authenticated', 'session_id', owner_session)::text, true)
from ff_test_ids;
set local role authenticated;
do $$
declare workspace uuid;
begin
  select workspace_id into workspace from ff_test_ids;
  begin
    perform public.ff_sync_pull(workspace, 0, 10);
    raise exception 'FAIL: revoked session retained access';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
rollback;
select 'PASS: solo sync contract; synthetic data rolled back' as result;
