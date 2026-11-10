-- Non-destructive validator update: preserve progress and notes for every outcome.
-- Completed visits still require final outcomes and consistent performed work.
begin;
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
    if (r.fields->>'appointment' is not null and r.fields->>'barn' <> target.fields->>'barn') or
       not exists(select 1 from ff_private.records c where c.workspace_id = p_workspace
         and c.kind = 'visitHorse' and c.fields->>'visit' = r.id::text) or
       (r.fields->>'appointment' is not null and exists(
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
       )) then raise exception 'Visit membership mismatch' using errcode = '23514'; end if;
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
       (target.fields->'completedAt' <> 'null'::jsonb
        and r.fields->>'outcomeRawValue' = 'notServiced' and count_items > 0) or
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
commit;
