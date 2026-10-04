-- P17-T296: courier creation command contract.
begin;

select plan(12);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_courier'
      and pg_get_function_identity_arguments(p.oid) = 'p_name text, p_idempotency_key text, p_contact_name text, p_contact_phone text, p_contact_email text, p_address text, p_notes text'
  ),
  'create_courier function exists with the locked signature'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_courier'
      and p.prosecdef
  ),
  'create_courier is security definer'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_courier(text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'authenticated can execute create_courier'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.create_courier(text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'anon cannot execute create_courier'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'INSERT'),
  'authenticated has no direct shipper INSERT privilege'
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
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'shippers'
      and c.conname = 'shippers_courier_code_format_chk'
  ),
  'courier code format constraint remains present'
);

select ok(
  exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'shipper_code_seq'
      and c.relkind = 'S'
  ),
  'courier code sequence exists'
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
      and table_name = 'audit_logs'
      and column_name in ('actor','action','entity_type','entity_id','before_data','after_data')
    group by table_schema, table_name
    having count(*) = 6
  ),
  'audit log fields required by courier creation exist'
);

select * from finish();
rollback;
