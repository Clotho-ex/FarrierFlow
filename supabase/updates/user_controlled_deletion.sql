-- Source-derived incremental update for user-controlled record deletion.
-- No records are deleted and no stored values are rewritten by this update.
-- Protocol three gates detached financial snapshots from older clients.
begin;
set local lock_timeout = '5s';
alter table ff_private.workspaces drop constraint workspaces_minimum_sync_protocol_check;
alter table ff_private.workspaces add constraint workspaces_minimum_sync_protocol_check
  check (minimum_sync_protocol in (1,2,3));
alter table ff_private.commits drop constraint commits_protocol_version_check;
alter table ff_private.commits add constraint commits_protocol_version_check
  check (protocol_version in (1,2,3));

create or replace function ff_private.kind_schema(p_kind text) returns jsonb
language sql immutable set search_path = '' as $$
  select '{"businessProfile":{"name":"string","phone":"string?","email":"string?","address":"string?","defaultInvoiceNote":"string?","defaultAppointmentDurationMinutes":"integer?","defaultInvoiceDueDays":"integer?","nextInvoiceNumber":"integer","currencyCode":"string"},"client":{"name":"string","phone":"string?","email":"string?","notes":"string?"},"barn":{"name":"string","address":"string?","contactNotes":"string?"},"service":{"name":"string","defaultAmountMinorUnits":"integer","currencyCode":"string","isArchived":"boolean"},"horse":{"name":"string","safetyNotes":"string?","appointmentIntervalWeeks":"integer","client":"uuid:client","currentBarn":"uuid:barn","defaultService":"uuid:service?"},"appointment":{"startDate":"date","notes":"string?","expectedDurationMinutes":"integer?","barn":"uuid:barn"},"appointmentHorse":{"appointment":"uuid:appointment","horse":"uuid:horse","plannedService":"uuid:service?"},"visit":{"startedAt":"date","completedAt":"date?","serviceLocationNameSnapshot":"string","serviceLocationAddressSnapshot":"string?","appointment":"uuid:appointment","barn":"uuid:barn"},"visitHorse":{"outcomeRawValue":"string","workNotes":"string?","visit":"uuid:visit","horse":"uuid:horse"},"photograph":{"createdAt":"date","pixelWidth":"integer","pixelHeight":"integer","byteCount":"integer","visitHorse":"uuid:visitHorse"},"workItem":{"billingHoldID":"uuid?","serviceNameSnapshot":"string","amountMinorUnits":"integer","currencyCode":"string","service":"uuid:service","visitHorse":"uuid:visitHorse"},"invoice":{"number":"integer","invoiceDate":"date","dueDate":"date?","note":"string?","statusRawValue":"string","clientNameSnapshot":"string","clientPhoneSnapshot":"string?","clientEmailSnapshot":"string?","businessNameSnapshot":"string","businessPhoneSnapshot":"string?","businessEmailSnapshot":"string?","businessAddressSnapshot":"string?","currencyCode":"string","client":"uuid:client?"},"invoiceVisit":{"visitDateSnapshot":"date","serviceLocationNameSnapshot":"string","serviceLocationAddressSnapshot":"string?","invoice":"uuid:invoice","sourceVisit":"uuid:visit?"},"invoiceLineItem":{"horseNameSnapshot":"string","serviceNameSnapshot":"string","amountMinorUnits":"integer","currencyCode":"string","invoiceVisit":"uuid:invoiceVisit","sourceWorkItem":"uuid:workItem?"},"payment":{"amountMinorUnits":"integer","currencyCode":"string","receivedAt":"date","methodRawValue":"string","sourceRawValue":"string","otherDescription":"string?","reference":"string?","note":"string?","invoice":"uuid:invoice"}}'::jsonb -> p_kind
$$;

create or replace function ff_private.validate_graph(p_workspace uuid) returns void
language plpgsql set search_path = '' as $$
declare r record; key text; rule text; target ff_private.records%rowtype;
        profile ff_private.records%rowtype; total numeric; count_items bigint;
begin
  for r in select * from ff_private.records where workspace_id = p_workspace and fields is not null loop
    perform ff_private.validate_fields(r.kind, r.fields);
    for key, rule in select * from jsonb_each_text(ff_private.kind_schema(r.kind)) loop
      if left(rule, 5) <> 'uuid:' or r.fields->key is null
         or r.fields->key = 'null'::jsonb then continue; end if;
      select * into target from ff_private.records
        where workspace_id = p_workspace and id = (r.fields->>key)::uuid;
      if not found or target.fields is null or target.kind <> rtrim(substr(rule, 6), '?') then
        raise exception 'Invalid workspace relationship' using errcode = '23503';
      end if;
    end loop;
    if r.kind = 'appointment' and not exists(
      select 1 from ff_private.records c where c.workspace_id = p_workspace
        and c.kind = 'appointmentHorse' and c.fields->>'appointment' = r.id::text
    ) then raise exception 'Appointment has no horses' using errcode = '23514'; end if;
    if r.kind = 'photograph' and (
      (r.fields->>'pixelWidth')::bigint <= 0 or (r.fields->>'pixelHeight')::bigint <= 0
      or (r.fields->>'byteCount')::bigint <= 0
    ) then raise exception 'Invalid photograph metadata' using errcode = '23514'; end if;
    if r.kind = 'visitHorse' and r.fields->>'outcomeRawValue' not in ('pending','serviced','notServiced') then
      raise exception 'Invalid visit outcome' using errcode = '23514';
    end if;
    if r.kind = 'invoice' then
      select coalesce(sum((l.fields->>'amountMinorUnits')::numeric), 0), count(*)
        into total, count_items from ff_private.records g
        join ff_private.records l on l.workspace_id = g.workspace_id
          and l.kind = 'invoiceLineItem' and l.fields->>'invoiceVisit' = g.id::text
        where g.workspace_id = p_workspace and g.kind = 'invoiceVisit'
          and g.fields->>'invoice' = r.id::text and l.fields is not null;
      if (r.fields->>'number')::bigint <= 0 or count_items = 0 or total > 9223372036854775807
         or r.fields->>'statusRawValue' not in ('unpaid','paid') then
        raise exception 'Invalid invoice graph' using errcode = '23514';
      end if;
      select * into target from ff_private.records p where p.workspace_id = p_workspace
        and p.kind = 'payment' and p.fields->>'invoice' = r.id::text;
      if (r.fields->>'statusRawValue' = 'paid') is distinct from (target.fields is not null)
         or (target.fields is not null and (
           (target.fields->>'amountMinorUnits')::numeric <> total
           or target.fields->>'currencyCode' <> r.fields->>'currencyCode')) then
        raise exception 'Invalid payment evidence' using errcode = '23514';
      end if;
    end if;
    if r.kind = 'payment' and (
      r.fields->>'methodRawValue' not in ('cash','bankTransfer','card','cheque','other')
      or r.fields->>'sourceRawValue' <> 'manual'
      or (r.fields->>'methodRawValue' = 'other' and
        coalesce(btrim(r.fields->>'otherDescription'), '') = '')
      or (r.fields->>'methodRawValue' <> 'other'
        and r.fields->'otherDescription' <> 'null'::jsonb)
    ) then raise exception 'Invalid payment method' using errcode = '23514'; end if;
  end loop;
  select * into profile from ff_private.records
    where workspace_id = p_workspace and kind = 'businessProfile' and fields is not null;
  if exists(select 1 from ff_private.records where workspace_id = p_workspace
            and kind = 'invoice' and fields is not null) and profile.fields is null then
    raise exception 'Invoice business profile missing' using errcode = '23514';
  end if;
  if profile.fields is not null and (
    (profile.fields->>'nextInvoiceNumber')::bigint <= 0 or
    (profile.fields->>'nextInvoiceNumber')::bigint <= coalesce((
      select max((fields->>'number')::bigint) from ff_private.records
      where workspace_id = p_workspace and kind = 'invoice' and fields is not null), 0)
  ) then raise exception 'Invalid invoice sequence' using errcode = '23514'; end if;
  if profile.fields is not null and exists(
    select 1 from ff_private.records where workspace_id = p_workspace
      and kind in ('service','workItem','invoice','invoiceLineItem','payment')
      and fields is not null and fields->>'currencyCode' <> profile.fields->>'currencyCode'
  ) then raise exception 'Business currency mismatch' using errcode = '23514'; end if;
  if exists(
    select 1 from ff_private.records a
      join ff_private.records h on h.workspace_id = a.workspace_id and h.id = (a.fields->>'horse')::uuid
      join ff_private.records p on p.workspace_id = a.workspace_id and p.id = (a.fields->>'appointment')::uuid
    where a.workspace_id = p_workspace and a.kind = 'appointmentHorse'
      and a.fields is not null and h.fields->>'currentBarn' <> p.fields->>'barn'
      and not exists (
        select 1 from ff_private.records v where v.workspace_id = p_workspace
          and v.kind = 'visit' and v.fields->>'appointment' = p.id::text
          and v.fields->'completedAt' <> 'null'::jsonb
      )
  ) then raise exception 'Horse outside appointment location' using errcode = '23514'; end if;
  for r in select * from ff_private.records where workspace_id = p_workspace
    and kind = 'visit' and fields is not null loop
    select * into target from ff_private.records where workspace_id = p_workspace
      and id = (r.fields->>'appointment')::uuid;
    if r.fields->>'barn' <> target.fields->>'barn' or
       not exists(select 1 from ff_private.records c where c.workspace_id = p_workspace
         and c.kind = 'visitHorse' and c.fields->>'visit' = r.id::text) or
       exists(
         (select fields->>'horse' from ff_private.records where workspace_id = p_workspace
           and kind = 'visitHorse' and fields->>'visit' = r.id::text
          except
          select fields->>'horse' from ff_private.records where workspace_id = p_workspace
           and kind = 'appointmentHorse' and fields->>'appointment' = target.id::text)
         union all
         (select fields->>'horse' from ff_private.records where workspace_id = p_workspace
           and kind = 'appointmentHorse' and fields->>'appointment' = target.id::text
          except
          select fields->>'horse' from ff_private.records where workspace_id = p_workspace
           and kind = 'visitHorse' and fields->>'visit' = r.id::text)
       ) then raise exception 'Visit membership mismatch' using errcode = '23514'; end if;
    if r.fields->'completedAt' <> 'null'::jsonb and (
      (r.fields->>'completedAt')::numeric < (r.fields->>'startedAt')::numeric or
      exists(select 1 from ff_private.records c where c.workspace_id = p_workspace
        and c.kind = 'visitHorse' and c.fields->>'visit' = r.id::text
        and c.fields->>'outcomeRawValue' = 'pending')
    ) then raise exception 'Invalid completed visit' using errcode = '23514'; end if;
  end loop;
  for r in select * from ff_private.records where workspace_id = p_workspace
    and kind = 'visitHorse' and fields is not null loop
    select * into target from ff_private.records where workspace_id = p_workspace
      and id = (r.fields->>'visit')::uuid;
    select count(*), coalesce(sum((fields->>'amountMinorUnits')::numeric),0)
      into count_items, total from ff_private.records
      where workspace_id = p_workspace and kind = 'workItem'
        and fields->>'visitHorse' = r.id::text;
    if total > 9223372036854775807 or
       (r.fields->>'outcomeRawValue' = 'notServiced' and count_items > 0) or
       (r.fields->>'outcomeRawValue' <> 'serviced'
        and r.fields->'workNotes' <> 'null'::jsonb) or
       (target.fields->'completedAt' <> 'null'::jsonb
        and r.fields->>'outcomeRawValue' = 'serviced' and count_items = 0) then
      raise exception 'Invalid visit work' using errcode = '23514';
    end if;
  end loop;
  if exists(
    select 1 from ff_private.records g where g.workspace_id = p_workspace
      and g.kind = 'invoiceVisit' and g.fields is not null and not exists(
        select 1 from ff_private.records l where l.workspace_id = p_workspace
          and l.kind = 'invoiceLineItem' and l.fields->>'invoiceVisit' = g.id::text)
  ) then raise exception 'Invoice group has no lines' using errcode = '23514'; end if;
  if exists(
    select 1 from ff_private.records w
      join ff_private.records s on s.workspace_id = w.workspace_id and s.id = (w.fields->>'service')::uuid
    where w.workspace_id = p_workspace and w.kind = 'workItem' and w.fields is not null
      and w.fields->>'currencyCode' <> s.fields->>'currencyCode'
  ) then raise exception 'Work currency mismatch' using errcode = '23514'; end if;
  if exists(
    select 1 from ff_private.records l
      join ff_private.records g on g.workspace_id = l.workspace_id and g.id = (l.fields->>'invoiceVisit')::uuid
      join ff_private.records i on i.workspace_id = l.workspace_id and i.id = (g.fields->>'invoice')::uuid
      join ff_private.records w on w.workspace_id = l.workspace_id and w.id = (l.fields->>'sourceWorkItem')::uuid
      join ff_private.records h on h.workspace_id = l.workspace_id and h.id = (w.fields->>'visitHorse')::uuid
      join ff_private.records horse on horse.workspace_id = l.workspace_id and horse.id = (h.fields->>'horse')::uuid
    where l.workspace_id = p_workspace and l.kind = 'invoiceLineItem' and l.fields is not null
      and (h.fields->>'visit' is distinct from g.fields->>'sourceVisit'
        or horse.fields->>'client' is distinct from i.fields->>'client'
        or l.fields->>'currencyCode' <> w.fields->>'currencyCode'
        or l.fields->>'currencyCode' <> i.fields->>'currencyCode')
  ) then raise exception 'Invoice source mismatch' using errcode = '23514'; end if;
  if exists(
    select 1 from ff_private.records l
      join ff_private.records g on g.workspace_id = l.workspace_id and g.id = (l.fields->>'invoiceVisit')::uuid
      join ff_private.records i on i.workspace_id = l.workspace_id and i.id = (g.fields->>'invoice')::uuid
    where l.workspace_id = p_workspace and l.kind = 'invoiceLineItem' and l.fields is not null
      and l.fields->>'currencyCode' is distinct from i.fields->>'currencyCode'
  ) then raise exception 'Invoice snapshot currency mismatch' using errcode = '23514'; end if;

end $$;

create or replace function ff_private.validate_history_deletions(p_workspace uuid, p_mutations jsonb)
returns void language plpgsql set search_path = '' as $$
declare item ff_private.records%rowtype; invoice ff_private.records%rowtype;
begin
  -- Read the original owners before any tombstone changes the relationship graph.
  for item in select r.* from ff_private.records r
    join jsonb_array_elements(p_mutations) m on r.id = (m.value->>'id')::uuid
    where r.workspace_id = p_workspace and r.fields is not null
      and r.kind in ('invoice','invoiceVisit','invoiceLineItem')
      and (m.value->'record' is null or m.value->'record' = 'null'::jsonb)
  loop
    if item.kind = 'invoice' then
      invoice := item;
    elsif item.kind = 'invoiceVisit' then
      select * into invoice from ff_private.records where workspace_id = p_workspace
        and id = (item.fields->>'invoice')::uuid and kind = 'invoice';
    else
      select i.* into invoice from ff_private.records g
        join ff_private.records i on i.workspace_id = g.workspace_id
          and i.id = (g.fields->>'invoice')::uuid and i.kind = 'invoice'
        where g.workspace_id = p_workspace and g.id = (item.fields->>'invoiceVisit')::uuid
          and g.kind = 'invoiceVisit';
    end if;
    if invoice.fields is null then
      raise exception 'Invoice history unavailable' using errcode = '23514';
    end if;
    if item.kind <> 'invoice' and not exists (
      select 1 from jsonb_array_elements(p_mutations) m
      where (m.value->>'id')::uuid = invoice.id and m.value->>'kind' = 'invoice'
        and (m.value->'record' is null or m.value->'record' = 'null'::jsonb)
    ) then
      raise exception 'Invoice snapshots require complete invoice deletion' using errcode = '23514';
    end if;
  end loop;
end $$;

create or replace function ff_private.validate_history_changes(p_workspace uuid, p_mutations jsonb, p_protocol integer)
returns void language plpgsql set search_path = '' as $$
declare mutation jsonb; old ff_private.records%rowtype; next jsonb;
        old_fields jsonb; new_fields jsonb; field text; source_id uuid; invoice_id uuid;
begin
  -- Validate against the original graph so mutation order cannot change authorization.
  for mutation in select value from jsonb_array_elements(p_mutations) loop
    select * into old from ff_private.records where workspace_id = p_workspace
      and id = (mutation->>'id')::uuid;
    next := mutation->'record'->'fields';
    if next = 'null'::jsonb then next := null; end if;
    if p_protocol < 3 and mutation->>'kind' in ('invoice','invoiceVisit','invoiceLineItem')
       and next is not null and (
         (mutation->>'kind' = 'invoice' and next->>'client' is null) or
         (mutation->>'kind' = 'invoiceVisit' and next->>'sourceVisit' is null) or
         (mutation->>'kind' = 'invoiceLineItem' and next->>'sourceWorkItem' is null)) then
      raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
    end if;
    if old.fields is null then continue; end if;
    if p_protocol < 3 and old.kind = 'invoice' and old.fields->>'statusRawValue' = 'paid'
       and next is null then
      raise exception 'Paid history cannot be deleted' using errcode = '23514';
    end if;
    if old.kind = 'workItem' and next is not null and old.fields->>'billingHoldID' is not null
       and old.fields->>'billingHoldID' is distinct from next->>'billingHoldID' then
      if p_protocol < 3 or next->>'billingHoldID' is not null or not exists(
        select 1 from ff_private.records i join jsonb_array_elements(p_mutations) m
          on i.id = (m.value->>'id')::uuid
        where i.workspace_id = p_workspace and i.kind = 'invoice' and i.fields is not null
          and i.id = (old.fields->>'billingHoldID')::uuid and m.value->>'kind' = 'invoice'
          and (m.value->'record' is null or m.value->'record' = 'null'::jsonb)
      ) then raise exception 'Immutable billing hold' using errcode = '23514'; end if;
    end if;
    if old.kind not in ('invoice','invoiceVisit','invoiceLineItem','payment','photograph')
       or next is null then continue; end if;
    old_fields := old.fields; new_fields := next;
    if old.kind = 'invoice' then
      old_fields := old_fields - 'statusRawValue'; new_fields := new_fields - 'statusRawValue';
    end if;
    field := case old.kind when 'invoice' then 'client' when 'invoiceVisit' then 'sourceVisit'
      when 'invoiceLineItem' then 'sourceWorkItem' else null end;
    if p_protocol >= 3 and field is not null and old_fields->field is distinct from new_fields->field
       and new_fields->field = 'null'::jsonb and old_fields->>field is not null then
      source_id := (old_fields->>field)::uuid;
      if not exists(select 1 from jsonb_array_elements(p_mutations) m
        where (m.value->>'id')::uuid = source_id
          and (m.value->'record' is null or m.value->'record' = 'null'::jsonb)) then
        invoice_id := null;
        if old.kind = 'invoiceLineItem' then
          select (g.fields->>'invoice')::uuid into invoice_id from ff_private.records g
            where g.workspace_id = p_workspace and g.id = (old.fields->>'invoiceVisit')::uuid;
        end if;
        if invoice_id is null or not exists(select 1 from jsonb_array_elements(p_mutations) m
          where (m.value->>'id')::uuid = source_id and m.value->>'kind' = 'workItem'
            and m.value->'record'->'fields'->>'billingHoldID' = invoice_id::text) then
          raise exception 'Snapshot source can only detach with source deletion or a billing hold' using errcode = '23514';
        end if;
      end if;
      old_fields := old_fields - field; new_fields := new_fields - field;
    end if;
    if old_fields is distinct from new_fields then
      raise exception 'Immutable history changed' using errcode = '23514';
    end if;
  end loop;
end $$;

create or replace function ff_private.sync_push_versioned(p_batch jsonb, p_protocol integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare actor uuid; workspace uuid; device uuid; operation uuid; fingerprint text;
        w ff_private.workspaces%rowtype; receipt ff_private.commits%rowtype;
        old ff_private.records%rowtype; mutation jsonb; record_value jsonb;
        fields_value jsonb; record_id uuid; record_kind text; expected bigint;
        next_revision bigint; normalized jsonb := '[]'::jsonb;
        new_line_ids uuid[] := '{}'; constraint_name text; has_holds boolean;
begin
  if p_protocol is null or p_protocol not in (1,2,3) then
    raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_batch) is distinct from 'object' or octet_length(p_batch::text) > 10485760
     or jsonb_typeof(p_batch->'mutations') is distinct from 'array'
     or jsonb_array_length(p_batch->'mutations') not between 1 and 10000 then
    raise exception 'Invalid batch size' using errcode = '22023';
  end if;
  workspace := (p_batch->>'workspaceID')::uuid;
  device := (p_batch->>'deviceID')::uuid;
  operation := (p_batch->>'operationID')::uuid;
  if workspace is null or device is null or operation is null then
    raise exception 'Missing batch identity' using errcode = '22023';
  end if;
  perform ff_private.require_access(workspace);
  select * into w from ff_private.workspaces where id = workspace for update;
  perform ff_private.require_access(workspace);
  actor := ff_private.actor();
  if not exists(select 1 from ff_private.devices d where d.workspace_id = workspace
                and d.id = device and d.user_id = actor) then
    raise exception 'Unregistered device' using errcode = '42501';
  end if;
  fingerprint := encode(sha256(convert_to(p_batch::text, 'UTF8')), 'hex');
  select * into receipt from ff_private.commits
    where workspace_id = workspace and operation_id = operation;
  if found then
    if receipt.request_hash <> fingerprint or receipt.protocol_version <> p_protocol then
      raise exception 'Operation identity reused' using errcode = '22023';
    end if;
    return jsonb_build_object('operationID', operation, 'revision', receipt.revision);
  end if;
  if p_protocol < w.minimum_sync_protocol then
    raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
  end if;
  if (select count(distinct value->>'id') from jsonb_array_elements(p_batch->'mutations'))
     <> jsonb_array_length(p_batch->'mutations') then
    raise exception 'Duplicate mutation identity' using errcode = '22023';
  end if;
  next_revision := w.revision + 1;
  perform ff_private.validate_history_deletions(workspace, p_batch->'mutations');
  perform ff_private.validate_history_changes(workspace, p_batch->'mutations', p_protocol);
  for mutation in select value from jsonb_array_elements(p_batch->'mutations') loop
    record_id := (mutation->>'id')::uuid;
    record_kind := mutation->>'kind';
    expected := (mutation->>'expectedRevision')::bigint;
    record_value := mutation->'record';
    if record_id is null or record_kind is null or expected is null or expected < 0 then
      raise exception 'Invalid mutation' using errcode = '22023';
    end if;
    select * into old from ff_private.records where workspace_id = workspace and id = record_id;
    if coalesce(old.revision, 0) <> expected then
      raise exception 'Record revision conflict' using errcode = '40001';
    end if;
    if old.id is not null and old.kind <> record_kind then
      raise exception 'Record kind changed' using errcode = '23514';
    end if;
    fields_value := null;
    if record_value is not null and record_value <> 'null'::jsonb then
      if (record_value->>'id')::uuid is distinct from record_id
         or record_value->>'kind' is distinct from record_kind then
        raise exception 'Record identity mismatch' using errcode = '22023';
      end if;
      fields_value := record_value->'fields';
      if record_kind = 'appointmentHorse' and old.fields->>'plannedService' is not null
         and not (fields_value ? 'plannedService') then
        raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
      end if;
      perform ff_private.validate_fields(record_kind, fields_value);
      if old.id is not null and old.fields is null then
        raise exception 'Deleted identity cannot be resurrected' using errcode = '23514';
      end if;
    end if;
    if record_kind = 'workItem' and fields_value is not null then
      if fields_value->>'billingHoldID' is not null and p_protocol < 2 then
        raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
      end if;

    end if;
    if record_kind = 'invoiceLineItem' and old.id is null and fields_value is not null then
      new_line_ids := array_append(new_line_ids, record_id);
    end if;

    if old.fields is not null and fields_value is null
       and record_kind = 'businessProfile' then
      raise exception 'Historical record cannot be deleted' using errcode = '23514';
    end if;
    if record_kind = 'invoice' and old.id is null and (
      device is distinct from w.invoicing_device_id or
      (p_batch->>'invoicingGeneration')::bigint is distinct from w.invoicing_generation
    ) then
      raise exception 'Designated invoicing device required' using errcode = '42501';
    end if;
    insert into ff_private.records(workspace_id, id, kind, fields, revision)
      values(workspace, record_id, record_kind, fields_value, next_revision)
      on conflict (workspace_id, id) do update
        set fields = excluded.fields, revision = excluded.revision;
    normalized := normalized || jsonb_build_array(jsonb_build_object(
      'id', record_id, 'kind', record_kind, 'expectedRevision', expected,
      'record', case when fields_value is null then null else
        jsonb_build_object('id', record_id, 'kind', record_kind, 'fields', fields_value) end));
  end loop;
  if exists (
    select 1 from ff_private.records l join ff_private.records source
      on source.workspace_id = l.workspace_id and source.id = (l.fields->>'sourceWorkItem')::uuid
    where l.workspace_id = workspace and l.id = any(new_line_ids)
      and source.fields->>'billingHoldID' is not null
  ) then raise exception 'FF_ALREADY_BILLED' using errcode = 'P0001'; end if;
  perform ff_private.validate_graph(workspace);
  select exists(select 1 from ff_private.records where workspace_id = workspace
    and kind = 'workItem' and fields->>'billingHoldID' is not null) into has_holds;
  update ff_private.workspaces set revision = next_revision,
    minimum_sync_protocol = greatest(minimum_sync_protocol, case when p_protocol = 3 then 3 when has_holds then 2 else 1 end)
    where id = workspace;
  insert into ff_private.commits(workspace_id, revision, operation_id, request_hash, mutations, protocol_version)
    values(workspace, next_revision, operation, fingerprint, normalized, p_protocol);
  perform realtime.send(jsonb_build_object('revision', next_revision),
    'changed', 'ff-workspace:' || workspace::text, true);
  return jsonb_build_object('operationID', operation, 'revision', next_revision);
exception when unique_violation then
  get stacked diagnostics constraint_name = CONSTRAINT_NAME;
  if constraint_name = 'ff_invoice_number' then
    raise exception 'FF_INVOICE_NUMBER_COLLISION' using errcode = 'P0001';
  elsif constraint_name = 'ff_single_billing' then
    raise exception 'FF_ALREADY_BILLED' using errcode = 'P0001';
  else raise;
  end if;
end $$;

create or replace function ff_private.sync_push_v3(p_batch jsonb) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_push_versioned(p_batch, 3)
$$;

create or replace function ff_private.sync_pull_versioned(p_workspace uuid, p_cursor bigint, p_limit integer, p_protocol integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare w ff_private.workspaces%rowtype; transactions jsonb; last_cursor bigint;
begin
  perform ff_private.require_access(p_workspace);
  select * into w from ff_private.workspaces where id = p_workspace for share;
  perform ff_private.require_access(p_workspace);
  if p_protocol is null or p_protocol not in (1,2,3) or p_protocol < w.minimum_sync_protocol then
    raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
  end if;
  if p_cursor is null or p_cursor < 0 or p_cursor > w.revision
     or p_limit is null or p_limit not between 1 and 50 then
    raise exception 'Invalid pull cursor' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'workspaceID', p_workspace, 'revision', revision, 'mutations', case when p_protocol = 1
      then ff_private.legacy_mutations(mutations) else mutations end
  ) order by revision), '[]'::jsonb), coalesce(max(revision), p_cursor)
    into transactions, last_cursor from (
      select revision, mutations from ff_private.commits where workspace_id = p_workspace
        and revision > p_cursor order by revision limit p_limit
    ) page;
  return jsonb_build_object('workspaceID', p_workspace, 'cursor', last_cursor,
    'hasMore', last_cursor < w.revision, 'transactions', transactions,
    'invoicingDeviceID', w.invoicing_device_id, 'invoicingGeneration', w.invoicing_generation);
end $$;

create or replace function ff_private.sync_pull_v3(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_pull_versioned(p_workspace, p_cursor, p_limit, 3)
$$;

create or replace function public.ff_sync_push_v3(p_batch jsonb) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_push_v3(p_batch)
$$;

create or replace function public.ff_sync_pull_v3(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_pull_v3(p_workspace, p_cursor, p_limit)
$$;
revoke all on function ff_private.validate_history_changes(uuid,jsonb,integer),
  ff_private.sync_push_v3(jsonb), ff_private.sync_pull_v3(uuid,bigint,integer)
  from public, anon, authenticated;
grant execute on function ff_private.sync_push_v3(jsonb), ff_private.sync_pull_v3(uuid,bigint,integer) to authenticated;
revoke all on function public.ff_sync_push_v3(jsonb), public.ff_sync_pull_v3(uuid,bigint,integer) from public, anon, authenticated;
grant execute on function public.ff_sync_push_v3(jsonb), public.ff_sync_pull_v3(uuid,bigint,integer) to authenticated;
commit;
