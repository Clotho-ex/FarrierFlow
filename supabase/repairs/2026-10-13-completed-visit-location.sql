-- Dev-only incremental repair. Completed visits retain their original location.
begin;
do $repair$
declare
  definition text := pg_get_functiondef('ff_private.validate_graph(uuid)'::regprocedure);
  prior text := $prior$and a.fields is not null and h.fields->>'currentBarn' <> p.fields->>'barn'
  ) then raise exception 'Horse outside appointment location'$prior$;
  corrected text := $corrected$and a.fields is not null and h.fields->>'currentBarn' <> p.fields->>'barn'
      and not exists (
        select 1 from ff_private.records v where v.workspace_id = p_workspace
          and v.kind = 'visit' and v.fields->>'appointment' = p.id::text
          and v.fields->'completedAt' <> 'null'::jsonb
      )
  ) then raise exception 'Horse outside appointment location'$corrected$;
begin
  if strpos(definition, corrected) > 0 then return; end if;
  if strpos(definition, prior) = 0
     or strpos(substr(definition, strpos(definition, prior) + length(prior)), prior) > 0 then
    raise exception 'Unexpected graph validator definition; repair refused';
  end if;
  execute replace(definition, prior, corrected);
end $repair$;
commit;
