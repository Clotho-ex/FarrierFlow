-- Reviewed source for the first FarrierFlow Dev sync contract.
-- Execute through Safari only after action-time access confirmation.
-- No data is dropped. App tables remain outside the exposed Data API schemas.
begin;
create schema ff_private;
revoke all on schema ff_private from public, anon, authenticated;
grant usage on schema ff_private to authenticated;

create table ff_private.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique,
  revision bigint not null default 0 check (revision >= 0),
  invoicing_device_id uuid,
  invoicing_generation bigint not null default 1 check (invoicing_generation > 0),
  deleting boolean not null default false,
  minimum_sync_protocol integer not null default 1 check (minimum_sync_protocol in (1,2))
);
create table ff_private.memberships (
  workspace_id uuid not null references ff_private.workspaces(id),
  user_id uuid not null,
  role text not null check (role in ('owner', 'member')),
  revoked_at timestamptz,
  primary key (workspace_id, user_id)
);
create index ff_memberships_user on ff_private.memberships(user_id, workspace_id);
create table ff_private.devices (
  workspace_id uuid not null references ff_private.workspaces(id),
  id uuid not null,
  user_id uuid not null,
  primary key (workspace_id, id)
);
create table ff_private.records (
  workspace_id uuid not null references ff_private.workspaces(id),
  id uuid not null,
  kind text not null check (kind in ('businessProfile', 'client', 'barn', 'service', 'horse', 'appointment', 'appointmentHorse', 'visit', 'visitHorse', 'photograph', 'workItem', 'invoice', 'invoiceVisit', 'invoiceLineItem', 'payment')),
  fields jsonb,
  revision bigint not null check (revision > 0),
  primary key (workspace_id, id),
  check (fields is null or jsonb_typeof(fields) = 'object')
);
create index ff_records_kind on ff_private.records(workspace_id, kind) where fields is not null;
create table ff_private.commits (
  workspace_id uuid not null references ff_private.workspaces(id),
  revision bigint not null check (revision > 0),
  operation_id uuid not null,
  request_hash text not null,
  protocol_version integer not null default 1 check (protocol_version in (1,2)),
  mutations jsonb not null check (jsonb_typeof(mutations) = 'array'),
  primary key (workspace_id, revision),
  unique (workspace_id, operation_id)
);
create table ff_private.photo_manifest (
  workspace_id uuid not null,
  id uuid not null,
  digest text not null check (digest ~ '^[a-f0-9]{64}$'),
  byte_count bigint not null check (byte_count > 0),
  primary key (workspace_id, id),
  foreign key (workspace_id, id) references ff_private.records(workspace_id, id)
);
create table ff_private.deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null unique references ff_private.workspaces(id),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  state text not null default 'pending' check (state in ('pending', 'running', 'complete')),
  attempts integer not null default 0,
  last_attempt_at timestamptz,
  last_error_code text,
  receipt_hash text not null unique check (receipt_hash ~ '^[a-f0-9]{64}$'),
  encrypted_apple_token jsonb,
  photos_removed boolean not null default false,
  records_removed boolean not null default false,
  apple_revoked boolean not null default false,
  lease_id uuid,
  lease_until timestamptz,
  check ((lease_id is null) = (lease_until is null))
);
alter table ff_private.workspaces enable row level security;
revoke all on table ff_private.workspaces from public, anon, authenticated;
alter table ff_private.memberships enable row level security;
revoke all on table ff_private.memberships from public, anon, authenticated;
alter table ff_private.devices enable row level security;
revoke all on table ff_private.devices from public, anon, authenticated;
alter table ff_private.records enable row level security;
revoke all on table ff_private.records from public, anon, authenticated;
alter table ff_private.commits enable row level security;
revoke all on table ff_private.commits from public, anon, authenticated;
alter table ff_private.photo_manifest enable row level security;
revoke all on table ff_private.photo_manifest from public, anon, authenticated;
alter table ff_private.deletion_jobs enable row level security;
revoke all on table ff_private.deletion_jobs from public, anon, authenticated;

create unique index ff_one_business_profile on ff_private.records(workspace_id)
  where kind = 'businessProfile' and fields is not null;
create unique index ff_invoice_number on ff_private.records(workspace_id, ((fields->>'number')::bigint))
  where kind = 'invoice' and fields is not null;
create unique index ff_single_billing on ff_private.records(workspace_id, (fields->>'sourceWorkItem'))
  where kind = 'invoiceLineItem' and fields is not null;
create unique index ff_invoice_visit_source on ff_private.records(workspace_id, (fields->>'invoice'), (fields->>'sourceVisit'))
  where kind = 'invoiceVisit' and fields is not null;
create unique index ff_single_payment on ff_private.records(workspace_id, (fields->>'invoice'))
  where kind = 'payment' and fields is not null;
create unique index ff_appointment_horse on ff_private.records(workspace_id, (fields->>'appointment'), (fields->>'horse'))
  where kind = 'appointmentHorse' and fields is not null;
create unique index ff_visit_horse on ff_private.records(workspace_id, (fields->>'visit'), (fields->>'horse'))
  where kind = 'visitHorse' and fields is not null;
create unique index ff_single_visit on ff_private.records(workspace_id, (fields->>'appointment'))
  where kind = 'visit' and fields is not null;
create unique index ff_work_service on ff_private.records(workspace_id, (fields->>'visitHorse'), (fields->>'service'))
  where kind = 'workItem' and fields is not null;

create function ff_private.actor() returns uuid
language sql volatile security definer set search_path = '' as $$
  select auth.uid() where auth.uid() is not null and exists (
    select 1 from auth.sessions s
    where s.id = nullif(auth.jwt()->>'session_id', '')::uuid and s.user_id = auth.uid()
  )
$$;
create function ff_private.can_access(p_workspace uuid) returns boolean
language sql volatile security definer set search_path = '' as $$
  select exists(
    select 1 from ff_private.memberships m
    join ff_private.workspaces w on w.id = m.workspace_id
    where m.workspace_id = p_workspace and m.user_id = ff_private.actor()
      and m.revoked_at is null and not w.deleting
  )
$$;
create function ff_private.require_access(p_workspace uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not ff_private.can_access(p_workspace) then
    raise exception 'Workspace access denied' using errcode = '42501';
  end if;
end $$;

create function ff_private.kind_schema(p_kind text) returns jsonb
language sql immutable set search_path = '' as $$
  select '{"businessProfile":{"name":"string","phone":"string?","email":"string?","address":"string?","defaultInvoiceNote":"string?","defaultAppointmentDurationMinutes":"integer?","defaultInvoiceDueDays":"integer?","nextInvoiceNumber":"integer","currencyCode":"string"},"client":{"name":"string","phone":"string?","email":"string?","notes":"string?"},"barn":{"name":"string","address":"string?","contactNotes":"string?"},"service":{"name":"string","defaultAmountMinorUnits":"integer","currencyCode":"string","isArchived":"boolean"},"horse":{"name":"string","safetyNotes":"string?","appointmentIntervalWeeks":"integer","client":"uuid:client","currentBarn":"uuid:barn","defaultService":"uuid:service?"},"appointment":{"startDate":"date","notes":"string?","expectedDurationMinutes":"integer?","barn":"uuid:barn"},"appointmentHorse":{"appointment":"uuid:appointment","horse":"uuid:horse","plannedService":"uuid:service?"},"visit":{"startedAt":"date","completedAt":"date?","serviceLocationNameSnapshot":"string","serviceLocationAddressSnapshot":"string?","appointment":"uuid:appointment","barn":"uuid:barn"},"visitHorse":{"outcomeRawValue":"string","workNotes":"string?","visit":"uuid:visit","horse":"uuid:horse"},"photograph":{"createdAt":"date","pixelWidth":"integer","pixelHeight":"integer","byteCount":"integer","visitHorse":"uuid:visitHorse"},"workItem":{"billingHoldID":"uuid?","serviceNameSnapshot":"string","amountMinorUnits":"integer","currencyCode":"string","service":"uuid:service","visitHorse":"uuid:visitHorse"},"invoice":{"number":"integer","invoiceDate":"date","dueDate":"date?","note":"string?","statusRawValue":"string","clientNameSnapshot":"string","clientPhoneSnapshot":"string?","clientEmailSnapshot":"string?","businessNameSnapshot":"string","businessPhoneSnapshot":"string?","businessEmailSnapshot":"string?","businessAddressSnapshot":"string?","currencyCode":"string","client":"uuid:client"},"invoiceVisit":{"visitDateSnapshot":"date","serviceLocationNameSnapshot":"string","serviceLocationAddressSnapshot":"string?","invoice":"uuid:invoice","sourceVisit":"uuid:visit"},"invoiceLineItem":{"horseNameSnapshot":"string","serviceNameSnapshot":"string","amountMinorUnits":"integer","currencyCode":"string","invoiceVisit":"uuid:invoiceVisit","sourceWorkItem":"uuid:workItem"},"payment":{"amountMinorUnits":"integer","currencyCode":"string","receivedAt":"date","methodRawValue":"string","sourceRawValue":"string","otherDescription":"string?","reference":"string?","note":"string?","invoice":"uuid:invoice"}}'::jsonb -> p_kind
$$;
create function ff_private.validate_fields(p_kind text, p_fields jsonb) returns void
language plpgsql set search_path = '' as $$
declare spec jsonb; key text; rule text; value jsonb; scalar text; optional boolean;
begin
  spec := ff_private.kind_schema(p_kind);
  if p_kind = 'appointmentHorse' and not (p_fields ? 'plannedService') then
    spec := spec - 'plannedService';
  end if;
  if p_kind = 'workItem' and not (p_fields ? 'billingHoldID') then
    spec := spec - 'billingHoldID';
  end if;
  if spec is null or jsonb_typeof(p_fields) is distinct from 'object'
     or (select array_agg(k order by k) from jsonb_object_keys(spec) k)
       is distinct from (select array_agg(k order by k) from jsonb_object_keys(p_fields) k) then
    raise exception 'Invalid record fields' using errcode = '22023';
  end if;
  for key, rule in select * from jsonb_each_text(spec) loop
    value := p_fields->key;
    optional := right(rule, 1) = '?';
    rule := rtrim(rule, '?');
    if optional and value = 'null'::jsonb then continue; end if;
    scalar := p_fields->>key;
    if rule = 'string' then
      if jsonb_typeof(value) is distinct from 'string' or octet_length(scalar) > 65536 then
        raise exception 'Invalid text field' using errcode = '22023';
      end if;
    elsif rule = 'boolean' then
      if jsonb_typeof(value) is distinct from 'boolean' then
        raise exception 'Invalid boolean field' using errcode = '22023';
      end if;
    elsif rule = 'integer' then
      if jsonb_typeof(value) is distinct from 'number' or scalar !~ '^-?[0-9]+$'
         or scalar::numeric not between -9223372036854775808 and 9223372036854775807 then
        raise exception 'Invalid integer field' using errcode = '22023';
      end if;
    elsif rule = 'date' then
      if jsonb_typeof(value) is distinct from 'string'
         or scalar !~ '^-?[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$'
         or abs(scalar::numeric) > 1000000000000 then
        raise exception 'Invalid date field' using errcode = '22023';
      end if;
    elsif rule = 'uuid' then
      if jsonb_typeof(value) is distinct from 'string'
         or scalar !~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' then
        raise exception 'Invalid opaque identity' using errcode = '22023';
      end if;
    elsif left(rule, 5) = 'uuid:' then
      if jsonb_typeof(value) is distinct from 'string'
         or scalar !~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' then
        raise exception 'Invalid relationship identity' using errcode = '22023';
      end if;
    else raise exception 'Unknown field type' using errcode = '22023';
    end if;
    if key in ('name','clientNameSnapshot','businessNameSnapshot','serviceNameSnapshot',
               'horseNameSnapshot','serviceLocationNameSnapshot') and btrim(scalar) = '' then
      raise exception 'Required name is empty' using errcode = '22023';
    end if;
    if key = 'currencyCode' and scalar not in ('USD','TRY','GBP','EUR','CAD','AUD','NZD','ZAR') then
      raise exception 'Unsupported currency' using errcode = '22023';
    end if;
    if key in ('amountMinorUnits','defaultAmountMinorUnits') and scalar::bigint < 0 then
      raise exception 'Negative amount' using errcode = '22023';
    end if;
  end loop;
end $$;

create function ff_private.validate_graph(p_workspace uuid) returns void
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
        and c.fields->>'outcomeRawValue' = 'pending') or
      not exists(select 1 from ff_private.records c where c.workspace_id = p_workspace
        and c.kind = 'visitHorse' and c.fields->>'visit' = r.id::text
        and c.fields->>'outcomeRawValue' = 'serviced')
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
      and (h.fields->>'visit' <> g.fields->>'sourceVisit'
        or horse.fields->>'client' <> i.fields->>'client'
        or l.fields->>'currencyCode' <> w.fields->>'currencyCode'
        or l.fields->>'currencyCode' <> i.fields->>'currencyCode')
  ) then raise exception 'Invoice source mismatch' using errcode = '23514'; end if;
end $$;

create function ff_private.bootstrap(p_device uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid; w ff_private.workspaces%rowtype; d ff_private.devices%rowtype;
begin
  actor := ff_private.actor();
  if actor is null or p_device is null then
    raise exception 'Live session required' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ff-owner:' || actor::text, 0));
  select * into w from ff_private.workspaces where owner_id = actor for update;
  if not found then
    insert into ff_private.workspaces(owner_id, invoicing_device_id)
      values(actor, p_device) returning * into w;
    insert into ff_private.memberships(workspace_id, user_id, role) values(w.id, actor, 'owner');
  end if;
  perform ff_private.require_access(w.id);
  select * into d from ff_private.devices where workspace_id = w.id and id = p_device;
  if found and d.user_id <> actor then
    raise exception 'Device access denied' using errcode = '42501';
  end if;
  insert into ff_private.devices(workspace_id, id, user_id) values(w.id, p_device, actor)
    on conflict (workspace_id, id) do nothing;
  return jsonb_build_object('workspaceID', w.id, 'deviceID', p_device,
    'invoicingDeviceID', w.invoicing_device_id, 'invoicingGeneration', w.invoicing_generation,
    'revision', w.revision, 'minimumProtocolVersion', w.minimum_sync_protocol);
end $$;

create function ff_private.validate_history_deletions(p_workspace uuid, p_mutations jsonb)
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
    if invoice.fields is null or invoice.fields->>'statusRawValue' is distinct from 'unpaid' then
      raise exception 'Paid history cannot be deleted' using errcode = '23514';
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

create function ff_private.sync_push_versioned(p_batch jsonb, p_protocol integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare actor uuid; workspace uuid; device uuid; operation uuid; fingerprint text;
        w ff_private.workspaces%rowtype; receipt ff_private.commits%rowtype;
        old ff_private.records%rowtype; mutation jsonb; record_value jsonb;
        fields_value jsonb; record_id uuid; record_kind text; expected bigint;
        next_revision bigint; normalized jsonb := '[]'::jsonb;
        new_line_ids uuid[] := '{}'; constraint_name text; has_holds boolean;
begin
  if p_protocol is null or p_protocol not in (1,2) then
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
      if fields_value->>'billingHoldID' is not null and p_protocol <> 2 then
        raise exception 'FF_PROTOCOL_UPGRADE_REQUIRED' using errcode = 'P0001';
      end if;
      if old.fields->>'billingHoldID' is not null and
         old.fields->>'billingHoldID' is distinct from fields_value->>'billingHoldID' then
        raise exception 'Immutable billing hold' using errcode = '23514';
      end if;
    end if;
    if record_kind = 'invoiceLineItem' and old.id is null and fields_value is not null then
      new_line_ids := array_append(new_line_ids, record_id);
    end if;
    if old.fields is not null and record_kind in ('invoice','invoiceVisit','invoiceLineItem','payment','photograph')
       and fields_value is not null and
       (case when record_kind = 'invoice' then old.fields - 'statusRawValue' else old.fields end)
       is distinct from
       (case when record_kind = 'invoice' then fields_value - 'statusRawValue' else fields_value end) then
      raise exception 'Immutable history changed' using errcode = '23514';
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
    minimum_sync_protocol = greatest(minimum_sync_protocol, case when has_holds then 2 else 1 end)
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

create function ff_private.sync_push(p_batch jsonb) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_push_versioned(p_batch, 1)
$$;
create function ff_private.sync_push_v2(p_batch jsonb) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_push_versioned(p_batch, 2)
$$;

create function ff_private.legacy_mutations(p_mutations jsonb) returns jsonb
language sql immutable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(case
    when m->>'kind' = 'workItem' and m->'record' <> 'null'::jsonb
      then jsonb_set(m, '{record,fields}', (m->'record'->'fields') - 'billingHoldID', false)
    else m end order by ordinal), '[]'::jsonb)
  from jsonb_array_elements(p_mutations) with ordinality as items(m, ordinal)
$$;

create function ff_private.sync_pull_versioned(p_workspace uuid, p_cursor bigint, p_limit integer, p_protocol integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare w ff_private.workspaces%rowtype; transactions jsonb; last_cursor bigint;
begin
  perform ff_private.require_access(p_workspace);
  select * into w from ff_private.workspaces where id = p_workspace for share;
  perform ff_private.require_access(p_workspace);
  if p_protocol is null or p_protocol not in (1,2) or p_protocol < w.minimum_sync_protocol then
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

create function ff_private.sync_pull(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_pull_versioned(p_workspace, p_cursor, p_limit, 1)
$$;
create function ff_private.sync_pull_v2(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security definer set search_path = '' as $$
  select ff_private.sync_pull_versioned(p_workspace, p_cursor, p_limit, 2)
$$;

create function public.ff_sync_bootstrap(p_device uuid) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.bootstrap(p_device)
$$;

create function ff_private.photo_allowed(p_name text, p_deleted boolean default false)
returns boolean language plpgsql security definer set search_path = '' as $$
declare workspace uuid; photo uuid; r ff_private.records%rowtype;
begin
  if p_name !~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}[.]jpg$' then
    return false;
  end if;
  workspace := split_part(p_name, '/', 1)::uuid;
  photo := split_part(split_part(p_name, '/', 2), '.', 1)::uuid;
  if not ff_private.can_access(workspace) then return false; end if;
  select * into r from ff_private.records where workspace_id = workspace and id = photo;
  return found and r.kind = 'photograph' and
    case when p_deleted then r.fields is null else r.fields is not null end;
end $$;

create function ff_private.photo_write_allowed(p_name text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare workspace uuid;
begin
  if not ff_private.photo_allowed(p_name) then return false; end if;
  workspace := split_part(p_name, '/', 1)::uuid;
  -- Share locks allow concurrent uploads but serialize their authorization
  -- against sync tombstones and deletion queueing's workspace update lock.
  perform 1 from ff_private.workspaces where id = workspace for share;
  return ff_private.photo_allowed(p_name);
end $$;

create function ff_private.photo_commit(p_workspace uuid, p_photo uuid, p_digest text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare path text; r ff_private.records%rowtype; existing ff_private.photo_manifest%rowtype;
begin
  perform ff_private.require_access(p_workspace);
  perform 1 from ff_private.workspaces where id = p_workspace for update;
  perform ff_private.require_access(p_workspace);
  path := p_workspace::text || '/' || p_photo::text || '.jpg';
  select * into r from ff_private.records
    where workspace_id = p_workspace and id = p_photo and kind = 'photograph' and fields is not null;
  if not found or p_digest is null or p_digest !~ '^[a-f0-9]{64}$' or not exists(
    select 1 from storage.objects where bucket_id = 'farrierflow-photos' and name = path
      and (metadata->>'size')::bigint = (r.fields->>'byteCount')::bigint
  ) then raise exception 'Photo object not verified' using errcode = '23514'; end if;
  select * into existing from ff_private.photo_manifest where workspace_id = p_workspace and id = p_photo;
  if found and existing.digest <> p_digest then
    raise exception 'Canonical photo cannot be replaced' using errcode = '23514';
  end if;
  insert into ff_private.photo_manifest(workspace_id, id, digest, byte_count)
    values(p_workspace, p_photo, p_digest, (r.fields->>'byteCount')::bigint)
    on conflict (workspace_id, id) do nothing;
  return jsonb_build_object('id', p_photo, 'digest', p_digest, 'byteCount', (r.fields->>'byteCount')::bigint);
end $$;

create function ff_private.photo_list(p_workspace uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform ff_private.require_access(p_workspace);
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'digest', p.digest, 'byteCount', p.byte_count))
    from ff_private.photo_manifest p join ff_private.records r
      on r.workspace_id = p.workspace_id and r.id = p.id
    where p.workspace_id = p_workspace and r.kind = 'photograph' and r.fields is not null
  ), '[]'::jsonb);
end $$;

create function ff_private.photo_delete_confirm(p_workspace uuid, p_photo uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform ff_private.require_access(p_workspace);
  perform 1 from ff_private.workspaces where id = p_workspace for update;
  perform ff_private.require_access(p_workspace);
  if not exists (
    select 1 from ff_private.records where workspace_id = p_workspace and id = p_photo
      and kind = 'photograph' and fields is null
  ) or exists (
    select 1 from storage.objects where bucket_id = 'farrierflow-photos'
      and name = p_workspace::text || '/' || p_photo::text || '.jpg'
  ) then raise exception 'Photo deletion not verified' using errcode = '23514'; end if;
  delete from ff_private.photo_manifest where workspace_id = p_workspace and id = p_photo;
  return jsonb_build_object('id', p_photo, 'deleted', true);
end $$;

create function public.ff_photo_delete_confirm(p_workspace uuid, p_photo uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.photo_delete_confirm(p_workspace, p_photo)
$$;

create function public.ff_photo_commit(p_workspace uuid, p_photo uuid, p_digest text)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.photo_commit(p_workspace, p_photo, p_digest)
$$;
create function public.ff_photo_list(p_workspace uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.photo_list(p_workspace)
$$;

create function ff_private.takeover(p_workspace uuid, p_device uuid, p_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare w ff_private.workspaces%rowtype; actor uuid; operation uuid := gen_random_uuid();
begin
  perform ff_private.require_access(p_workspace);
  select * into w from ff_private.workspaces where id = p_workspace for update;
  perform ff_private.require_access(p_workspace);
  actor := ff_private.actor();
  if w.owner_id is distinct from actor or not exists(
    select 1 from ff_private.devices where workspace_id = p_workspace
      and id = p_device and user_id = actor
  ) then raise exception 'Owner device required' using errcode = '42501'; end if;
  if p_generation is null or p_generation <> w.invoicing_generation then
    raise exception 'Invoicing generation changed' using errcode = '40001';
  end if;
  update ff_private.workspaces set invoicing_device_id = p_device,
    invoicing_generation = invoicing_generation + 1, revision = revision + 1
    where id = p_workspace returning * into w;
  insert into ff_private.commits(workspace_id, revision, operation_id, request_hash, mutations)
    values(p_workspace, w.revision, operation, 'device-takeover', '[]'::jsonb);
  perform realtime.send(jsonb_build_object('revision', w.revision),
    'changed', 'ff-workspace:' || p_workspace::text, true);
  return jsonb_build_object('invoicingDeviceID', p_device,
    'invoicingGeneration', w.invoicing_generation, 'revision', w.revision);
end $$;

create function ff_private.request_deletion(p_workspace uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  -- A recent Supabase session alone is not fresh Apple authorization and does
  -- not supply a revocable Apple token. The verified server endpoint queues it.
  raise exception 'Verified Apple account deletion required' using errcode = '42501';
end $$;

create function public.ff_invoicing_takeover(p_workspace uuid, p_device uuid, p_generation bigint)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.takeover(p_workspace, p_device, p_generation)
$$;
create function public.ff_request_cloud_deletion(p_workspace uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.request_deletion(p_workspace)
$$;
create function public.ff_sync_push(p_batch jsonb) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_push(p_batch)
$$;
create function public.ff_sync_pull(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_pull(p_workspace, p_cursor, p_limit)
$$;

create function public.ff_sync_bootstrap_v2(p_device uuid) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.bootstrap(p_device)
$$;
create function public.ff_sync_push_v2(p_batch jsonb) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_push_v2(p_batch)
$$;
create function public.ff_sync_pull_v2(p_workspace uuid, p_cursor bigint, p_limit integer) returns jsonb
language sql security invoker set search_path = '' as $$
  select ff_private.sync_pull_v2(p_workspace, p_cursor, p_limit)
$$;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
  values('farrierflow-photos', 'farrierflow-photos', false, 20971520, array['image/jpeg']);

create policy ff_photo_read on storage.objects for select to authenticated
using (bucket_id = 'farrierflow-photos' and (
  ff_private.photo_allowed(name) or (
    storage.allow_any_operation(array['object.delete', 'object.delete_many'])
    and ff_private.photo_allowed(name, true)
  )
));
create policy ff_photo_insert on storage.objects for insert to authenticated
with check (bucket_id = 'farrierflow-photos' and ff_private.photo_write_allowed(name));
create policy ff_photo_delete on storage.objects for delete to authenticated
using (bucket_id = 'farrierflow-photos' and ff_private.photo_allowed(name, true));

create policy ff_workspace_broadcast_read on realtime.messages
for select to authenticated using (
  extension = 'broadcast' and topic like 'ff-workspace:%'
  and ff_private.can_access(nullif(split_part(topic, ':', 2), '')::uuid)
);

revoke all on all functions in schema ff_private from public, anon, authenticated;
grant execute on function ff_private.can_access(uuid),
  ff_private.bootstrap(uuid), ff_private.sync_push(jsonb),
  ff_private.sync_pull(uuid,bigint,integer) to authenticated;
grant execute on function ff_private.photo_allowed(text,boolean), ff_private.photo_write_allowed(text),
  ff_private.photo_commit(uuid,uuid,text), ff_private.photo_list(uuid),
  ff_private.photo_delete_confirm(uuid,uuid) to authenticated;
grant execute on function ff_private.takeover(uuid,uuid,bigint),
  ff_private.request_deletion(uuid) to authenticated;
revoke all on function public.ff_sync_bootstrap(uuid), public.ff_sync_push(jsonb),
  public.ff_sync_pull(uuid,bigint,integer) from public, anon, authenticated;
grant execute on function public.ff_sync_bootstrap(uuid), public.ff_sync_push(jsonb),
  public.ff_sync_pull(uuid,bigint,integer) to authenticated;
revoke all on function public.ff_photo_commit(uuid,uuid,text),
  public.ff_photo_list(uuid) from public, anon, authenticated;
grant execute on function public.ff_photo_commit(uuid,uuid,text),
  public.ff_photo_list(uuid) to authenticated;
revoke all on function public.ff_photo_delete_confirm(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ff_photo_delete_confirm(uuid,uuid) to authenticated;
revoke all on function public.ff_invoicing_takeover(uuid,uuid,bigint),
  public.ff_request_cloud_deletion(uuid) from public, anon, authenticated;
grant execute on function public.ff_invoicing_takeover(uuid,uuid,bigint),
  public.ff_request_cloud_deletion(uuid) to authenticated;
grant execute on function ff_private.sync_push_v2(jsonb), ff_private.sync_pull_v2(uuid,bigint,integer) to authenticated;
revoke all on function public.ff_sync_bootstrap_v2(uuid), public.ff_sync_push_v2(jsonb),
  public.ff_sync_pull_v2(uuid,bigint,integer) from public, anon, authenticated;
grant execute on function public.ff_sync_bootstrap_v2(uuid), public.ff_sync_push_v2(jsonb),
  public.ff_sync_pull_v2(uuid,bigint,integer) to authenticated;
commit;
