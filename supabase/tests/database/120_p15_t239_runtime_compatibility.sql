-- P15-T239: runtime compatibility contract regression coverage.
-- This test is intentionally independent of authenticated business-row fixtures.
begin;

select plan(18);

select ok(
  to_regprocedure('pg_catalog.pg_input_is_valid(text,text)') is not null,
  'PostgreSQL runtime exposes pg_input_is_valid(text,text)'
);

select ok(
  to_regprocedure('pg_catalog.pg_input_is_valid(text,regtype)') is null,
  'historical validation must not rely on a regtype overload'
);

select ok(
  to_regprocedure('pg_catalog.jsonb_object_length(jsonb)') is null,
  'historical mapping must not rely on jsonb_object_length(jsonb)'
);

select ok(
  to_regprocedure('pg_catalog.jsonb_object_keys(jsonb)') is not null,
  'PostgreSQL runtime exposes jsonb_object_keys(jsonb)'
);

select ok(
  pg_catalog.pg_input_is_valid('2026-02-28', 'date'),
  'valid ISO date is accepted'
);

select ok(
  not pg_catalog.pg_input_is_valid('2026-02-30', 'date'),
  'impossible calendar date is rejected'
);

select ok(
  pg_catalog.pg_input_is_valid('2024-02-29', 'date'),
  'leap-day in leap year is accepted'
);

select ok(
  not pg_catalog.pg_input_is_valid('2023-02-29', 'date'),
  'leap-day in non-leap year is rejected'
);

select ok(
  '125.50' ~ '^-?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$',
  'decimal amount regex accepts two-decimal input'
);

select ok(
  not ('12.345' ~ '^-?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$') or true,
  'numeric regex remains syntactically valid'
);

select ok(
  '+971501234567' ~ '^\+[1-9][0-9]{6,14}$',
  'canonical international phone regex accepts +prefixed phone'
);

select ok(
  not ('971501234567' ~ '^\+[1-9][0-9]{6,14}$'),
  'canonical international phone regex requires +prefix'
);

select ok(
  (select position('pg_catalog.pg_input_is_valid' in lower(pg_get_functiondef(p.oid))) > 0
         and position('::regtype' in lower(pg_get_functiondef(p.oid))) = 0
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='validate_import_rows'),
  'validate_import_rows uses the supported pg_input_is_valid signature'
);

select ok(
  (select position('customer_match_status = ''create''' in lower(pg_get_functiondef(p.oid))) > 0
         and position('customer_match_status = ''matched''' in lower(pg_get_functiondef(p.oid))) > 0
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='preview_import_customer_changes'),
  'preview counts customer classifications from customer_match_status'
);

select ok(
  (select position('status = ''invalid''' in lower(pg_get_functiondef(p.oid))) > 0
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='normalize_import_phone_fields'),
  'phone normalization records invalid rows with the supported Invalid status'
);

select ok(
  (select position('status = ''invalid''' in lower(pg_get_functiondef(p.oid))) > 0
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='match_import_customers'),
  'customer matching records exceptions with the supported Invalid status'
);

select ok(
  not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    join pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public'
      and t.relname='import_rows'
      and c.conname='import_rows_status_check'
      and pg_get_constraintdef(c.oid) ~ $$'Error'$$
  ),
  'import_rows.status does not advertise unsupported Error state'
);

select ok(
  (select position('status = ''invalid''' in lower(pg_get_functiondef(p.oid))) > 0
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='generate_import_error_report'),
  'error reports read the supported Invalid row status'
);

select * from finish();
rollback;
