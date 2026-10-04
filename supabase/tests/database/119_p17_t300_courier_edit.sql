-- P17-T300: courier edit command contract.
begin;

select plan(14);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'update_courier'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, text, text, text, text, text'
  ),
  'update_courier exists with the locked eight-argument signature'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'update_courier'
      and p.prosecdef
  ),
  'update_courier is security definer'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.update_courier(uuid,text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'authenticated can execute update_courier'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.update_courier(uuid,text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'anon cannot execute update_courier'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'INSERT'),
  'authenticated still has no direct shipper INSERT privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'UPDATE'),
  'authenticated has no direct shipper UPDATE privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'DELETE'),
  'authenticated has no direct shipper DELETE privilege'
);

select ok(
  has_table_privilege('authenticated', 'public.shippers', 'SELECT'),
  'authenticated retains shipper SELECT access'
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
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shippers'
      and column_name = 'courier_code'
  ),
  'courier_code remains on the existing shippers master'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shippers'
      and column_name = 'active'
  ),
  'active state remains part of the courier master'
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
  'audit log fields required by courier edit exist'
);

select * from finish();
rollback;
