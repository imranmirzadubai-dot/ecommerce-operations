begin;
select plan(8);

select has_function(
  'public',
  'normalize_uae_phone',
  array['text'],
  'UAE phone normalizer exists'
);
select is(
  public.normalize_uae_phone('050 123 4567'),
  '+971501234567',
  'normalizes local UAE mobile notation'
);
select is(
  public.normalize_uae_phone('+971 50 123 4567'),
  '+971501234567',
  'normalizes international UAE mobile notation'
);
select is(
  public.normalize_uae_phone('00971 50 123 4567'),
  '+971501234567',
  'normalizes 00-prefixed UAE mobile notation'
);
select is(
  public.normalize_uae_phone('971501234567'),
  '+971501234567',
  'normalizes country-code notation without plus'
);
select is(
  public.normalize_uae_phone('04 123 4567'),
  '+97141234567',
  'normalizes UAE fixed-line notation'
);
select is(
  public.normalize_uae_phone('not a phone'),
  null,
  'returns null for non-numeric input'
);
select is(
  public.normalize_uae_phone('123'),
  null,
  'returns null for invalid UAE number length'
);

select * from finish();
rollback;
