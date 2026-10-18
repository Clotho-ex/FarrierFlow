-- Dev-only incremental repair. Pending Visit outcomes may retain saved work.
begin;
do $repair$
declare
  definition text := pg_get_functiondef('ff_private.validate_graph(uuid)'::regprocedure);
  prior text := $prior$(r.fields->>'outcomeRawValue' <> 'serviced'
        and (count_items > 0 or r.fields->'workNotes' <> 'null'::jsonb))$prior$;
  corrected text := $corrected$(r.fields->>'outcomeRawValue' = 'notServiced' and count_items > 0) or
       (r.fields->>'outcomeRawValue' <> 'serviced'
        and r.fields->'workNotes' <> 'null'::jsonb)$corrected$;
begin
  if strpos(definition, corrected) > 0 then return; end if;
  if strpos(definition, prior) = 0
     or strpos(substr(definition, strpos(definition, prior) + length(prior)), prior) > 0 then
    raise exception 'Unexpected graph validator definition; repair refused';
  end if;
  execute replace(definition, prior, corrected);
end $repair$;
commit;
