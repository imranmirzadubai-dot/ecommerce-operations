begin;

-- P5-T090: UAE phone normalization.
-- Canonical representation is E.164-style +971 followed by the UAE
-- national significant number. Local, 971, +971 and 00971 prefixes are accepted.
create or replace function public.normalize_uae_phone(p_phone text)
returns text
language plpgsql
immutable
strict
set search_path = pg_catalog, public
as $$
declare
  v_digits text;
begin
  v_digits := regexp_replace(btrim(p_phone), '[^0-9]', '', 'g');

  if v_digits = '' then
    return null;
  end if;

  if left(v_digits, 5) = '00971' then
    v_digits := substring(v_digits from 6);
  elsif left(v_digits, 3) = '971' then
    v_digits := substring(v_digits from 4);
  elsif left(v_digits, 1) = '0' then
    v_digits := substring(v_digits from 2);
  end if;

  -- UAE mobile NSNs are nine digits; UAE fixed-line NSNs are eight digits
  -- and begin with a geographic area code (2-9).
  if length(v_digits) = 9 then
    return '+971' || v_digits;
  elsif length(v_digits) = 8 and left(v_digits, 1) in ('2','3','4','6','7','9') then
    return '+971' || v_digits;
  end if;

  return null;
end;
$$;

revoke all on function public.normalize_uae_phone(text) from public, anon;
grant execute on function public.normalize_uae_phone(text) to authenticated;

-- Keep normalized_phone synchronized with the UAE canonical form whenever
-- customer phone data is inserted or changed.
create or replace function public.set_customer_normalized_phone()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.normalized_phone := public.normalize_uae_phone(new.phone);
  return new;
end;
$$;

revoke all on function public.set_customer_normalized_phone() from public, anon, authenticated;

drop trigger if exists trg_set_customer_normalized_phone on public.customers;
create trigger trg_set_customer_normalized_phone
before insert or update of phone on public.customers
for each row
execute function public.set_customer_normalized_phone();

-- Reconcile existing customer phone values to the same canonical representation.
update public.customers
set normalized_phone = public.normalize_uae_phone(phone)
where normalized_phone is distinct from public.normalize_uae_phone(phone);

commit;
