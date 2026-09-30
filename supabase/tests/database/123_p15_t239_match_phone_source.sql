begin;
select plan(2);
select ok(
  position('normalized_data ->> p_phone_field' in lower(pg_get_functiondef(p.oid))) > 0,
  'match function reads the configured phone field from normalized_data'
);
select ok(
  position('r.normalized_phone' in lower(pg_get_functiondef(p.oid))) = 0,
  'match function does not reference nonexistent import_rows.normalized_phone'
);
select * from finish();
rollback;