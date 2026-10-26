-- Self-contained synthetic paid graph. Everything rolls back after validation.
begin;
create temporary table ff_visit_history_workspace as select gen_random_uuid() as id;
insert into ff_private.workspaces(id, owner_id)
  select id, gen_random_uuid() from ff_visit_history_workspace;
create temporary table ff_visit_history_ids(label text primary key, id uuid not null);
insert into ff_visit_history_ids(label, id) values
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

insert into ff_private.records(workspace_id, id, kind, fields, revision)
  select (select id from ff_visit_history_workspace), (r->>'id')::uuid,
    r->>'kind', r->'record'->'fields', 1
  from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'businessProfile'), 'kind', 'businessProfile', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'businessProfile'), 'kind', 'businessProfile', 'fields', jsonb_build_object('name', 'Test Business', 'phone', null, 'email', null, 'address', null, 'defaultInvoiceNote', null, 'defaultAppointmentDurationMinutes', null, 'defaultInvoiceDueDays', 14, 'nextInvoiceNumber', 2, 'currencyCode', 'GBP'))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'client'), 'kind', 'client', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'client'), 'kind', 'client', 'fields', jsonb_build_object('name', 'Pat', 'phone', null, 'email', null, 'notes', null))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'barn'), 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'barn'), 'kind', 'barn', 'fields', jsonb_build_object('name', 'Old Stable', 'address', '1 Stable Lane', 'contactNotes', null))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'movedBarn'), 'kind', 'barn', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'movedBarn'), 'kind', 'barn', 'fields', jsonb_build_object('name', 'New Stable', 'address', null, 'contactNotes', null))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'service'), 'kind', 'service', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'service'), 'kind', 'service', 'fields', jsonb_build_object('name', 'Front Shoes', 'defaultAmountMinorUnits', 12500, 'currencyCode', 'GBP', 'isArchived', false))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'horse'), 'kind', 'horse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'horse'), 'kind', 'horse', 'fields', jsonb_build_object('name', 'Milo', 'safetyNotes', null, 'appointmentIntervalWeeks', 6, 'client', (select id from ff_visit_history_ids where label = 'client')::text, 'currentBarn', (select id from ff_visit_history_ids where label = 'movedBarn')::text, 'defaultService', (select id from ff_visit_history_ids where label = 'service')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'appointment'), 'kind', 'appointment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'appointment'), 'kind', 'appointment', 'fields', jsonb_build_object('startDate', '123.0', 'notes', null, 'expectedDurationMinutes', null, 'barn', (select id from ff_visit_history_ids where label = 'barn')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'appointmentHorse'), 'kind', 'appointmentHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'appointmentHorse'), 'kind', 'appointmentHorse', 'fields', jsonb_build_object('appointment', (select id from ff_visit_history_ids where label = 'appointment')::text, 'horse', (select id from ff_visit_history_ids where label = 'horse')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'visit'), 'kind', 'visit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'visit'), 'kind', 'visit', 'fields', jsonb_build_object('startedAt', '123.0', 'completedAt', '133.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'appointment', (select id from ff_visit_history_ids where label = 'appointment')::text, 'barn', (select id from ff_visit_history_ids where label = 'barn')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'visitHorse'), 'kind', 'visitHorse', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'visitHorse'), 'kind', 'visitHorse', 'fields', jsonb_build_object('outcomeRawValue', 'serviced', 'workNotes', 'Front shoes', 'visit', (select id from ff_visit_history_ids where label = 'visit')::text, 'horse', (select id from ff_visit_history_ids where label = 'horse')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'photograph'), 'kind', 'photograph', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'photograph'), 'kind', 'photograph', 'fields', jsonb_build_object('createdAt', '123.0', 'pixelWidth', 1200, 'pixelHeight', 900, 'byteCount', 42, 'visitHorse', (select id from ff_visit_history_ids where label = 'visitHorse')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'workItem'), 'kind', 'workItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'workItem'), 'kind', 'workItem', 'fields', jsonb_build_object('serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'service', (select id from ff_visit_history_ids where label = 'service')::text, 'visitHorse', (select id from ff_visit_history_ids where label = 'visitHorse')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoice'), 'kind', 'invoice', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoice'), 'kind', 'invoice', 'fields', jsonb_build_object('number', 1, 'invoiceDate', '500.0', 'dueDate', '600.0', 'note', 'Thank you.', 'statusRawValue', 'paid', 'clientNameSnapshot', 'Pat', 'clientPhoneSnapshot', null, 'clientEmailSnapshot', null, 'businessNameSnapshot', 'Test Business', 'businessPhoneSnapshot', null, 'businessEmailSnapshot', null, 'businessAddressSnapshot', null, 'currencyCode', 'GBP', 'client', (select id from ff_visit_history_ids where label = 'client')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoiceVisit'), 'kind', 'invoiceVisit', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoiceVisit'), 'kind', 'invoiceVisit', 'fields', jsonb_build_object('visitDateSnapshot', '123.0', 'serviceLocationNameSnapshot', 'Old Stable', 'serviceLocationAddressSnapshot', '1 Stable Lane', 'invoice', (select id from ff_visit_history_ids where label = 'invoice')::text, 'sourceVisit', (select id from ff_visit_history_ids where label = 'visit')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoiceLineItem'), 'kind', 'invoiceLineItem', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'invoiceLineItem'), 'kind', 'invoiceLineItem', 'fields', jsonb_build_object('horseNameSnapshot', 'Milo', 'serviceNameSnapshot', 'Front Shoes', 'amountMinorUnits', 12500, 'currencyCode', 'GBP', 'invoiceVisit', (select id from ff_visit_history_ids where label = 'invoiceVisit')::text, 'sourceWorkItem', (select id from ff_visit_history_ids where label = 'workItem')::text))),
      jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'payment'), 'kind', 'payment', 'expectedRevision', 0, 'record', jsonb_build_object('id', (select id from ff_visit_history_ids where label = 'payment'), 'kind', 'payment', 'fields', jsonb_build_object('amountMinorUnits', 12500, 'currencyCode', 'GBP', 'receivedAt', '700.0', 'methodRawValue', 'cheque', 'sourceRawValue', 'manual', 'otherDescription', null, 'reference', 'CHEQUE-1', 'note', null, 'invoice', (select id from ff_visit_history_ids where label = 'invoice')::text)))
    )) r;
select ff_private.validate_graph((select id from ff_visit_history_workspace));

do $$
declare workspace uuid := (select id from ff_visit_history_workspace);
        visit_id uuid; appointment_id uuid; work_before jsonb; invoice_before jsonb; photos_before jsonb;
begin
  select id,(fields->>'appointment')::uuid into visit_id,appointment_id
    from ff_private.records where workspace_id=workspace and kind='visit';
  select jsonb_agg(fields order by id) into work_before from ff_private.records
    where workspace_id=workspace and kind='workItem';
  select jsonb_agg(fields order by id) into invoice_before from ff_private.records
    where workspace_id=workspace and kind in ('invoice','invoiceVisit','invoiceLineItem','payment');
  select jsonb_agg(fields order by id) into photos_before from ff_private.records
    where workspace_id=workspace and kind='photograph';
  update ff_private.records set fields=null where workspace_id=workspace
    and (id=appointment_id or kind='appointmentHorse');
  update ff_private.records set fields=jsonb_set(fields,'{appointment}','null')
    where workspace_id=workspace and id=visit_id;
  perform ff_private.validate_graph(workspace);
  if work_before is distinct from (select jsonb_agg(fields order by id) from ff_private.records
      where workspace_id=workspace and kind='workItem') then raise exception 'Recorded work changed'; end if;
  if invoice_before is distinct from (select jsonb_agg(fields order by id) from ff_private.records
      where workspace_id=workspace and kind in ('invoice','invoiceVisit','invoiceLineItem','payment'))
    then raise exception 'Invoice history changed'; end if;
  if photos_before is distinct from (select jsonb_agg(fields order by id) from ff_private.records
      where workspace_id=workspace and kind='photograph') then raise exception 'Photos changed'; end if;
  -- An absent source schedule is allowed; a dangling reference still fails.
  begin
    update ff_private.records set fields=jsonb_set(fields,'{appointment}',to_jsonb(gen_random_uuid()::text))
      where workspace_id=workspace and id=visit_id;
    perform ff_private.validate_graph(workspace);
    raise exception 'Dangling appointment accepted';
  exception when foreign_key_violation then null;
  end;
end $$;
select 'PASS: scheduling deletion preserves recorded work, photos and all financial snapshots' as result;
rollback;
