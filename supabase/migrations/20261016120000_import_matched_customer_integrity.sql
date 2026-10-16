-- Protect historical imports from stale or mismatched customer matches.
-- This migration only replaces the validation block in the existing command function.
begin;

do $migration$
declare
  v_definition text;
  v_needle text := $needle$      if v_customer_id is null then
        raise exception using errcode='55000', message='Matched import row is missing matched customer';
      end if;
      v_customer_reuse_count := v_customer_reuse_count + 1;$needle$;
  v_replacement text := $replacement$      if v_customer_id is null or not exists (
        select 1
        from public.customers c
        where c.id = v_customer_id
          and c.normalized_phone = v_phone
      ) then
        raise exception using errcode='55000', message='Matched import row customer does not match normalized phone';
      end if;
      v_customer_reuse_count := v_customer_reuse_count + 1;$replacement$;
begin
  select pg_get_functiondef('public.import_historical_batch(uuid,jsonb,text)'::regprocedure)
    into v_definition;

  if position(v_replacement in v_definition) > 0 then
    return;
  end if;

  if position(v_needle in v_definition) = 0 then
    raise exception 'Expected import_historical_batch matched-customer guard was not found; refusing to modify function';
  end if;

  execute replace(v_definition, v_needle, v_replacement);
end;
$migration$;

commit;
