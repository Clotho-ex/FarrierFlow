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
end $$;
reset role;
create temporary table ff_seed as select * from ff_private.records
  where workspace_id = (select workspace_id from ff_test_ids);
grant select on ff_seed to authenticated;
create function pg_temp.ff_delete_mutation(label text, replacement jsonb) returns jsonb
language sql as $$
  select jsonb_build_object('id',r.id,'kind',r.kind,'expectedRevision',r.revision,
    'record', case when replacement is null then null else
      jsonb_build_object('id',r.id,'kind',r.kind,'fields',replacement) end)
  from ff_seed r join ff_test_graph_ids g on r.id=g.id where g.label=$1
$$;
create function pg_temp.ff_delete_batch(mutations jsonb) returns jsonb language sql as $$
  select jsonb_build_object('operationID',gen_random_uuid(),'workspaceID',workspace_id,
    'deviceID',device_id,'invoicingGeneration',1,'mutations',$1) from ff_test_ids
$$;
create function pg_temp.ff_seed_fields(label text) returns jsonb language sql as $$
  select r.fields from ff_seed r join ff_test_graph_ids g on g.id=r.id where g.label=$1
$$;
set local role authenticated;
do $$
declare f record; mutations jsonb; receipt jsonb; prior jsonb; after jsonb;
        invoice uuid; source uuid; fields jsonb;
begin
  select * into f from ff_test_ids;
  select id into invoice from ff_test_graph_ids where label='invoice';
  select id into source from ff_test_graph_ids where label='workItem';
  prior := public.ff_sync_pull_v3(f.workspace_id,0,50);
  -- The operational graph may be removed while its paid financial snapshots remain.
  begin
    select jsonb_agg(pg_temp.ff_delete_mutation(label,null)) into mutations
      from ff_test_graph_ids where label in ('client','horse','appointment','appointmentHorse',
        'visit','visitHorse','photograph','workItem');
    mutations := mutations || jsonb_build_array(
      pg_temp.ff_delete_mutation('invoice',jsonb_set(pg_temp.ff_seed_fields('invoice'),'{client}','null')),
      pg_temp.ff_delete_mutation('invoiceVisit',jsonb_set(pg_temp.ff_seed_fields('invoiceVisit'),'{sourceVisit}','null')),
      pg_temp.ff_delete_mutation('invoiceLineItem',jsonb_set(pg_temp.ff_seed_fields('invoiceLineItem'),'{sourceWorkItem}','null')));
    receipt := public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations));
    after := public.ff_sync_pull_v3(f.workspace_id,2,50);
    perform pg_temp.ff_expect(jsonb_array_length(after->'transactions'->0->'mutations')=11,
      'client cascade and retained snapshots commit atomically');
    perform pg_temp.ff_expect((public.ff_sync_bootstrap_v2(f.device_id)->>'minimumProtocolVersion')::int=3,
      'new deletion semantics require protocol three');
    begin
      perform public.ff_sync_pull_v2(f.workspace_id,0,50);
      raise exception 'FAIL: old client received detached history';
    exception when sqlstate 'P0001' then
      if sqlerrm <> 'FF_PROTOCOL_UPGRADE_REQUIRED' then raise; end if;
    end;
    raise exception using errcode='P7777';
  exception when sqlstate 'P7777' then null; end;
  perform pg_temp.ff_expect(public.ff_sync_pull_v3(f.workspace_id,0,50)=prior,'case rollback restores original graph');
  begin
    mutations := jsonb_build_array(
      pg_temp.ff_delete_mutation('service',null),pg_temp.ff_delete_mutation('workItem',null),
      pg_temp.ff_delete_mutation('horse',jsonb_set(pg_temp.ff_seed_fields('horse'),'{defaultService}','null')),
      pg_temp.ff_delete_mutation('visitHorse',pg_temp.ff_seed_fields('visitHorse') || jsonb_build_object('outcomeRawValue','notServiced','workNotes',null)),
      pg_temp.ff_delete_mutation('invoiceLineItem',jsonb_set(pg_temp.ff_seed_fields('invoiceLineItem'),'{sourceWorkItem}','null')));
    perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations));
    perform pg_temp.ff_expect(jsonb_array_length(public.ff_sync_pull_v3(f.workspace_id,2,50)->'transactions')=1,
      'service cascade allows completed visit with no serviced horses');
    raise exception using errcode='P7777';
  exception when sqlstate 'P7777' then null; end;
  -- No source detachment or financial rewrite is allowed without a valid witness.
  begin
    perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(jsonb_build_array(
      pg_temp.ff_delete_mutation('invoiceLineItem',jsonb_set(pg_temp.ff_seed_fields('invoiceLineItem'),'{sourceWorkItem}','null')))));
    raise exception 'FAIL: invoice source detached without deletion or billing hold';
  exception when check_violation then null; end;
  begin
    perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(jsonb_build_array(
      pg_temp.ff_delete_mutation('invoice',jsonb_set(pg_temp.ff_seed_fields('invoice'),'{number}','99')))));
    raise exception 'FAIL: financial snapshot changed';
  exception when check_violation then null; end;
  begin
    perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(jsonb_build_array(
      pg_temp.ff_delete_mutation('invoiceLineItem',null))));
    raise exception 'FAIL: partial paid snapshot deleted';
  exception when check_violation then null; end;
  -- Correct billed operational work without modifying the paid invoice.
  begin
    fields := pg_temp.ff_seed_fields('workItem') || jsonb_build_object('billingHoldID',invoice::text,'amountMinorUnits',15000);
    perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(jsonb_build_array(
      pg_temp.ff_delete_mutation('workItem',fields),
      pg_temp.ff_delete_mutation('invoiceLineItem',jsonb_set(pg_temp.ff_seed_fields('invoiceLineItem'),'{sourceWorkItem}','null')))));
    begin
      mutations := jsonb_build_array(jsonb_build_object('id',source,'kind','workItem','expectedRevision',3,
        'record',jsonb_build_object('id',source,'kind','workItem','fields',fields || jsonb_build_object('billingHoldID',null))));
      perform public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations));
      raise exception 'FAIL: hold cleared without explicit invoice deletion';
    exception when check_violation then null; end;
    select jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'expectedRevision',
      case when r.kind='invoiceLineItem' then 3 else r.revision end,'record',null)) into mutations
      from ff_seed r where r.kind in ('invoice','invoiceVisit','invoiceLineItem','payment');
    mutations := mutations || jsonb_build_array(jsonb_build_object('id',source,'kind','workItem','expectedRevision',3,
      'record',jsonb_build_object('id',source,'kind','workItem','fields',fields || jsonb_build_object('billingHoldID',null))));
    receipt := public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations));
    perform pg_temp.ff_expect((receipt->>'revision')::int=4,'paid invoice deletion releases only its matching hold');
    raise exception using errcode='P7777';
  exception when sqlstate 'P7777' then null; end;
  -- Paid invoices can also be removed without changing their operational work.
  begin
    select jsonb_agg(pg_temp.ff_delete_mutation(label,null)) into mutations
      from ff_test_graph_ids where label in ('invoice','invoiceVisit','invoiceLineItem','payment');
    receipt := public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations));
    after := public.ff_sync_pull_v3(f.workspace_id,2,50);
    perform pg_temp.ff_expect(jsonb_array_length(after->'transactions'->0->'mutations')=4,
      'paid invoice and payment deletion produces complete tombstones');
    perform pg_temp.ff_expect(public.ff_sync_push_v3(pg_temp.ff_delete_batch(mutations)) is null,'unreachable');
  exception when serialization_failure then null; end;
  perform pg_temp.ff_expect(public.ff_sync_pull_v3(f.workspace_id,0,50)=prior,'failed stale batch rolls back complete case');
end $$;
reset role;
select pg_temp.ff_expect(not has_function_privilege('anon','public.ff_sync_push_v3(jsonb)','execute'),
  'anonymous protocol three access denied');
select pg_temp.ff_expect(not has_table_privilege('authenticated','ff_private.records','insert,update,delete'),
  'direct business writes remain denied');
select 'PASS: user-controlled deletion preserves paid invoices, protects immutable values, and gates old clients' as result;
rollback;
