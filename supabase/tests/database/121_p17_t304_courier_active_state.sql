-- P17-T304: courier active/inactive state command contract.
begin;

select plan(13);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'set_courier_active'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, boolean, text'
  ),
  'set_courier_active exists with the locked three-argument signature'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'set_courier_active'
      and p.prosecdef
  ),
  'set_courier_active is security definer'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.set_courier_active(uuid,boolean,text)',
    'EXECUTE'
  ),
  'authenticated can execute set_courier_active'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.set_courier_active(uuid,boolean,text)',
    'EXECUTE'
  ),
  'anon cannot execute set_courier_active'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'INSERT'),
  'authenticated still has no direct shipper INSERT privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'UPDATE'),
  'authenticated still has no direct shipper UPDATE privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'DELETE'),
  'authenticated still has no direct shipper DELETE privilege'
);

select ok(
  has_table_privilege('authenticated', 'public.shippers', 'SELECT'),
  'authenticated retains shipper SELECT access'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shippers'
      and column_name = 'active'
  ),
  'active state remains on the existing shippers master'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'claim_command_idempotency'
  )
  and exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'complete_command_idempotency'
  ),
  'command idempotency foundation is available'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shipper'
  ) is false,
  'no replacement courier table is introduced'
);

select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'parcels'
      and c.conname = 'parcels_shipper_id_fkey'
  ),
  'parcel-level shipper relationship remains present'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'audit_logs'
      and column_name in ('actor','action','entity_type','entity_id','before_data','after_data')
    group by table_schema, table_name
    having count(*) = 6
  ),
  'audit log fields required by courier state changes exist'
);

select * from finish();
rollback;
