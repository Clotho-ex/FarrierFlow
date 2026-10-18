rollback;
begin;
create or replace function ff_private.validate_fields(p_kind text, p_fields jsonb) returns void
language plpgsql set search_path = '' as $$
declare spec jsonb; key text; rule text; value jsonb; scalar text; optional boolean;
begin
  spec := ff_private.kind_schema(p_kind);
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
commit;
