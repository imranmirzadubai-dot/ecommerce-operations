begin;

select plan(28);

-- Use deterministic identities only inside this rollback-scoped test transaction.
set local role postgres;

create temporary table test_users (
  id uuid primary key,
  email text not null,
  role_name text not null
) on commit drop;

insert into test_users (id, email, role_name) values
  ('00000000-0000-0000-0000-000000000208'::uuid, 'rls-sales@example.test', 'sales'),
  ('00000000-0000-0000-0000-000000000209'::uuid, 'rls-admin@example.test', 'admin');

-- Local Supabase auth.users accepts these minimal fields; all generated defaults remain intact.
insert into auth.users (id, aud, role, email, encrypted_password)
select id, 'authenticated', 'authenticated', email, 'test-only'
from test_users;

insert into public.profiles (id, name, email, role, active)
select id, role_name || ' RLS Test User', email, role_name, true
from test_users;

insert into public.customers (id, name, phone, normalized_phone, city)
values ('00000000-0000-0000-0000-000000000210'::uuid, 'RLS Visible Customer', '0500000210', '0500000210', 'Ajman');

insert into public.orders (id, customer_id, original_amount, lifecycle_state, created_by)
values (
  '00000000-0000-0000-0000-000000000211'::uuid,
  '00000000-0000-0000-0000-000000000210'::uuid,
  99.00,
  'Confirmed',
  '00000000-0000-0000-0000-000000000209'::uuid
);

insert into public.audit_logs (id, actor, action, entity_type, entity_id)
values (
  '00000000-0000-0000-0000-000000000212'::uuid,
  '00000000-0000-0000-0000-000000000209'::uuid,
  'test', 'order', '00000000-0000-0000-0000-000000000211'::uuid
);

insert into public.import_batches (id, source_system, source_file, initiated_by, status)
values (
  '00000000-0000-0000-0000-000000000213'::uuid,
  'RLS_TEST', 'rls.csv', '00000000-0000-0000-0000-000000000209'::uuid, 'Ready'
);

insert into public.import_rows (id, batch_id, source_row_number, raw_data, status)
values (
  '00000000-0000-0000-0000-000000000214'::uuid,
  '00000000-0000-0000-0000-000000000213'::uuid,
  1, '{"test":true}'::jsonb, 'Pending'
);

-- Anonymous has no table privileges, so direct reads must fail.
set local role anon;
select throws_ok(
  $$select count(*) from public.customers$$,
  '42501',
  null,
  'anon cannot directly read customers'
);

select throws_ok(
  $$select count(*) from public.orders$$,
  '42501',
  null,
  'anon cannot directly read orders'
);

-- Sales user: positive access to operational data through the RLS policy.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000208', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(public.app_role(), 'sales', 'active sales profile resolves through app_role');
select is((select count(*) from public.profiles), 1::bigint, 'sales sees only its own profile');
select is((select count(*) from public.customers), 1::bigint, 'sales can read customers');
select is((select count(*) from public.orders), 1::bigint, 'sales can read orders');
select is((select count(*) from public.audit_logs), 0::bigint, 'sales cannot read admin-only audit logs');
select is((select count(*) from public.import_batches), 0::bigint, 'sales cannot read admin-only import batches');
select is((select count(*) from public.import_rows), 0::bigint, 'sales cannot read admin-only import rows');

-- RLS does not grant direct mutation; authenticated is intentionally SELECT-only.
select throws_ok(
  $$insert into public.customers (name) values ('should fail')$$,
  '42501',
  null,
  'authenticated cannot directly insert customers'
);

select throws_ok(
  $$update public.orders set notes = 'should fail'$$,
  '42501',
  null,
  'authenticated cannot directly update orders'
);

select throws_ok(
  $$delete from public.customers$$,
  '42501',
  null,
  'authenticated cannot directly delete customers'
);

-- Sales must not be able to see another user's profile.
select is(
  (select count(*) from public.profiles where id = '00000000-0000-0000-0000-000000000209'::uuid),
  0::bigint,
  'sales cannot read another profile'
);

-- Admin user: positive access to admin-only data plus normal operational data.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000209', true);

select is(public.app_role(), 'admin', 'active admin profile resolves through app_role');
select is((select count(*) from public.profiles), 1::bigint, 'admin also sees only its own profile');
select is((select count(*) from public.customers), 1::bigint, 'admin can read customers');
select is((select count(*) from public.orders), 1::bigint, 'admin can read orders');
select is((select count(*) from public.audit_logs), 1::bigint, 'admin can read audit logs');
select is((select count(*) from public.import_batches), 1::bigint, 'admin can read import batches');
select is((select count(*) from public.import_rows), 1::bigint, 'admin can read import rows');

-- Inactive users lose the role-derived RLS access.
set local role postgres;
update public.profiles
set active = false
where id = '00000000-0000-0000-0000-000000000208'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000208', true);

select is(public.app_role(), null, 'inactive user resolves to no application role');
select is((select count(*) from public.customers), 0::bigint, 'inactive user loses customer access');
select is((select count(*) from public.orders), 0::bigint, 'inactive user loses order access');
select is((select count(*) from public.profiles), 0::bigint, 'inactive user loses profile self-read');

select * from finish();
rollback;
