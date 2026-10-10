begin;

-- Restore the UAE phone normalizer required by create_order.
-- Forward-only helper-function repair: no table, data, or schema changes.
create or replace function public.normalize_uae_phone(p_phone text)
returns text
language plpgsql
immutable
parallel safe
set search_path = pg_catalog
as $function$
declare
  v_digits text;
  v_national text;
begin
  v_digits := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');

  if v_digits = '' then
    return null;
  end if;

  if v_digits like '00971%' then
    v_national := substring(v_digits from 6);
  elsif v_digits like '971%' then
    v_national := substring(v_digits from 4);
  else
    v_national := v_digits;
  end if;

  -- Accept local trunk-prefix notation, including the common +971 050 typo.
  if v_national like '0%' then
    v_national := substring(v_national from 2);
  end if;

  -- UAE mobile numbers have 9 national digits starting with 5.
  -- UAE fixed-line numbers have 8 national digits starting with 2-7 or 9.
  if v_national ~ '^5[0-9]{8}$'
     or v_national ~ '^[2-79][0-9]{7}$' then
    return '+971' || v_national;
  end if;

  return null;
end;
$function$;

revoke all on function public.normalize_uae_phone(text) from public, anon;
grant execute on function public.normalize_uae_phone(text) to authenticated;

commit;
