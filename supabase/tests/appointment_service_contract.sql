-- Synthetic appointment-service sync checks; every record rolls back.
begin;
create function pg_temp.appointment_mutation(id uuid, kind text, revision bigint, fields jsonb)
returns jsonb language sql as $$
  select jsonb_build_object('id', id, 'kind', kind, 'expectedRevision', revision,
    'record', jsonb_build_object('id', id, 'kind', kind, 'fields', fields))
$$;
create temporary table appointment_service_ids as select
  gen_random_uuid() owner_id, gen_random_uuid() session_id, gen_random_uuid() device_id;
insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at)
select owner_id, 'authenticated', 'authenticated', owner_id::text || '@example.invalid', now(), now(), now()
from appointment_service_ids;
insert into auth.sessions(id, user_id, created_at, updated_at)
select session_id, owner_id, now(), now() from appointment_service_ids;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', owner_id, 'role', 'authenticated', 'session_id', session_id)::text, true)
from appointment_service_ids;
grant select on appointment_service_ids to authenticated;
set local role authenticated;
do $$
declare device uuid; workspace uuid; client uuid := gen_random_uuid(); barn uuid := gen_random_uuid();
  service uuid := gen_random_uuid(); horse uuid := gen_random_uuid(); appointment uuid := gen_random_uuid();
  member uuid := gen_random_uuid(); fields jsonb; mutations jsonb; batch jsonb; receipt jsonb; revision bigint;
begin
  select device_id into device from appointment_service_ids;
  workspace := (public.ff_sync_bootstrap(device)->>'workspaceID')::uuid;
  fields := jsonb_build_object('appointment', appointment, 'horse', horse, 'plannedService', service);
  mutations := jsonb_build_array(
    pg_temp.appointment_mutation(client, 'client', 0, jsonb_build_object('name', 'Pat', 'phone', null, 'email', null, 'notes', null)),
    pg_temp.appointment_mutation(barn, 'barn', 0, jsonb_build_object('name', 'Stable', 'address', null, 'contactNotes', null)),
    pg_temp.appointment_mutation(service, 'service', 0, jsonb_build_object('name', 'Trim', 'defaultAmountMinorUnits', 5000, 'currencyCode', 'USD', 'isArchived', false)),
    pg_temp.appointment_mutation(horse, 'horse', 0, jsonb_build_object('name', 'Milo', 'safetyNotes', null, 'appointmentIntervalWeeks', 6, 'client', client, 'currentBarn', barn, 'defaultService', null)),
    pg_temp.appointment_mutation(appointment, 'appointment', 0, jsonb_build_object('startDate', '100.0', 'notes', null, 'expectedDurationMinutes', null, 'barn', barn)),
    pg_temp.appointment_mutation(member, 'appointmentHorse', 0, fields));
  batch := jsonb_build_object('operationID', gen_random_uuid(), 'workspaceID', workspace,
    'deviceID', device, 'invoicingGeneration', 1, 'mutations', mutations);
  receipt := public.ff_sync_push_v2(batch);
  revision := (receipt->>'revision')::bigint;
  if not exists(select 1 from jsonb_array_elements(
      public.ff_sync_pull_v2(workspace, 0, 50)->'transactions'->0->'mutations') m
      where m->>'id' = member::text and m->'record'->'fields'->>'plannedService' = service::text) then
    raise exception 'FAIL: appointment service did not round trip';
  end if;
  -- An older client cannot silently clear a plan it cannot represent.
  batch := jsonb_set(batch, '{operationID}', to_jsonb(gen_random_uuid()));
  batch := jsonb_set(batch, '{mutations}', jsonb_build_array(
    pg_temp.appointment_mutation(member, 'appointmentHorse', revision, fields - 'plannedService')));
  begin
    perform public.ff_sync_push_v2(batch);
    raise exception 'FAIL: legacy rewrite erased appointment service';
  exception when raise_exception then
    if sqlerrm <> 'FF_PROTOCOL_UPGRADE_REQUIRED' then raise; end if;
  end;
  -- Relationship validation must reject a nonexistent service.
  batch := jsonb_set(batch, '{operationID}', to_jsonb(gen_random_uuid()));
  batch := jsonb_set(batch, '{mutations}', jsonb_build_array(
    pg_temp.appointment_mutation(member, 'appointmentHorse', revision,
      jsonb_set(fields, '{plannedService}', to_jsonb(gen_random_uuid())))));
  begin
    perform public.ff_sync_push_v2(batch);
    raise exception 'FAIL: missing service was accepted';
  exception when foreign_key_violation then null;
  end;
  -- A current client can intentionally clear the override.
  batch := jsonb_set(batch, '{operationID}', to_jsonb(gen_random_uuid()));
  batch := jsonb_set(batch, '{mutations}', jsonb_build_array(
    pg_temp.appointment_mutation(member, 'appointmentHorse', revision,
      jsonb_set(fields, '{plannedService}', 'null'::jsonb))));
  receipt := public.ff_sync_push_v2(batch);
  if (receipt->>'revision')::bigint <> revision + 1 then
    raise exception 'FAIL: clearing the appointment service did not commit';
  end if;
end $$;
reset role;
rollback;

select 'PASS: appointment service contract; synthetic data rolled back'::text as result;
