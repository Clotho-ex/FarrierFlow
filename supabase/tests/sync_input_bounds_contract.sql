-- FarrierFlow Dev only. Input rejection through exposed RPCs; always roll back.
begin;
create temporary table ff_bounds_before as select
  (select count(*) from ff_private.workspaces) as workspaces,
  (select count(*) from ff_private.records) as records,
  (select count(*) from ff_private.commits) as commits;

set local role authenticated;
do $$
declare batch jsonb; protocol integer; rejected boolean;
begin
  for protocol in 1..2 loop
    for batch in
      select value from (values
        (null::jsonb), ('null'::jsonb), ('[]'::jsonb), ('{}'::jsonb),
        ('{"mutations":null}'::jsonb), ('{"mutations":{}}'::jsonb),
        ('{"mutations":[]}'::jsonb),
        (jsonb_build_object('mutations', (select jsonb_agg('{}'::jsonb) from generate_series(1,10001)))),
        (jsonb_build_object('mutations', jsonb_build_array('{}'::jsonb), 'oversized', repeat('x',10485761)))
      ) cases(value)
    loop
      rejected := false;
      begin
        if protocol = 1 then perform public.ff_sync_push(batch);
        else perform public.ff_sync_push_v2(batch); end if;
      exception when invalid_parameter_value then
        if sqlerrm <> 'Invalid batch size' then raise; end if;
        rejected := true;
      end;
      if not rejected then raise exception 'FAIL: invalid batch accepted for protocol %',protocol; end if;
    end loop;
    rejected := false;
    begin
      batch := jsonb_build_object('mutations',jsonb_build_array('{}'::jsonb));
      if protocol = 1 then perform public.ff_sync_push(batch);
      else perform public.ff_sync_push_v2(batch); end if;
    exception when invalid_parameter_value then
      if sqlerrm <> 'Missing batch identity' then raise; end if;
      rejected := true;
    end;
    if not rejected then raise exception 'FAIL: missing identity accepted for protocol %',protocol; end if;
  end loop;
end $$;
reset role;

do $$
declare before_row ff_bounds_before%rowtype;
begin
  select * into before_row from ff_bounds_before;
  if before_row.workspaces <> (select count(*) from ff_private.workspaces)
    or before_row.records <> (select count(*) from ff_private.records)
    or before_row.commits <> (select count(*) from ff_private.commits) then
    raise exception 'FAIL: rejected input changed business state';
  end if;
end $$;
select 'PASS: both sync protocols reject malformed/oversized batches and missing identities without business writes' as result;
rollback;
