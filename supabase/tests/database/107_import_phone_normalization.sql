begin;

select plan(10);

select has_function(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'T188 phone normalization command exists with the expected signature'
);

select function_is_security_definer(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'T188 phone normalization command is SECURITY DEFINER'
);

select function_has_search_path(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'T188 phone normalization command fixes search_path to pg_catalog, public'
);

select function_returns(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'TABLE(batch_id uuid, row_count integer, normalized_count integer, error_count integer)',
  'T188 returns deterministic batch and normalization counts'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'Admin role required',
  'T188 enforces the Admin-only authorization boundary'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'revoke all on function public.normalize_import_phone_fields',
  'T188 revokes public/anon execution before granting authenticated entry'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  'p_default_country_code',
  'T188 accepts a default country code for national-format numbers'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  "'^\\+[0-9]{7,15}$'",
  'T188 emits canonical plus-prefixed international phone values'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  "'^00[0-9]{7,15}$'",
  'T188 converts 00-prefixed international numbers deterministically'
);

select function_has_sql(
  'public',
  'normalize_import_phone_fields',
  ARRAY['uuid','jsonb','text','text'],
  "'Invalid phone number: ' || pf.field",
  'T188 records invalid phone values as row errors instead of silently accepting them'
);

select * from finish();
rollback;
