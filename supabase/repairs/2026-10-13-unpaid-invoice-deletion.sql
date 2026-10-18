-- Dev-only incremental repair. Preserve explicit unpaid deletion, not partial history edits.
begin;
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
revoke all on function ff_private.validate_history_deletions(uuid,jsonb) from public, anon, authenticated;
do $repair$
declare
  definition text := pg_get_functiondef('ff_private.sync_push(jsonb)'::regprocedure);
  insertion text := $insertion$  next_revision := w.revision + 1;
  for mutation$insertion$;
  corrected_insertion text := $insertion$  next_revision := w.revision + 1;
  perform ff_private.validate_history_deletions(workspace, p_batch->'mutations');
  for mutation$insertion$;
  prior text := $prior$and record_kind in ('invoice','invoiceVisit','invoiceLineItem','businessProfile') then$prior$;
  corrected text := $corrected$and record_kind = 'businessProfile' then$corrected$;
begin
  if strpos(definition, corrected_insertion) > 0 and strpos(definition, corrected) > 0 then return; end if;
  if strpos(definition, insertion) = 0 or strpos(definition, prior) = 0 then
    raise exception 'Unexpected sync push definition; repair refused';
  end if;
  execute replace(replace(definition, insertion, corrected_insertion), prior, corrected);
end $repair$;
commit;
