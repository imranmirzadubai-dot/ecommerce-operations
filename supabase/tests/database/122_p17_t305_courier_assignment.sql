-- P17-T305: courier parcel assignment / reassignment command contract.
begin;

select plan(18);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  ),
  'assign_parcel_shipper keeps the locked three-argument contract'
);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and p.prosecdef
      and p.proconfig @> array['search_path=""']
  ),
  'assignment command is security definer with an empty pinned search_path'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.assign_parcel_shipper(uuid,uuid,text)',
    'EXECUTE'
  ),
  'authenticated can execute courier assignment'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.assign_parcel_shipper(uuid,uuid,text)',
    'EXECUTE'
  ),
  'anon cannot execute courier assignment'
);

select ok(
  not has_table_privilege('authenticated', 'public.parcels', 'UPDATE'),
  'authenticated still has no direct parcel UPDATE privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.shippers', 'UPDATE'),
  'authenticated still has no direct courier UPDATE privilege'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) = 'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%public.app_role() not in (''operations'',''admin'')%',
  'assignment checks the caller role server-side'
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
  'parcel-level shipper relationship remains the authoritative relationship'
);

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'shipper_id'
  ),
  'no order-level shipper relationship is introduced'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%v_state <> ''Prepared''%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%for update%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%v_shipper_active%'
  ,
  'assignment locks the parcel and validates Prepared plus target courier state'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%ShipperAssigned%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%ShipperReassigned%'
  ,
  'assignment and reassignment emit distinct order events'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%claim_command_idempotency%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%complete_command_idempotency%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%assign_parcel_shipper%'
  ,
  'assignment remains idempotent and retry safe'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%claim_command_idempotency%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%complete_command_idempotency%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%''assign_parcel_shipper''%'
  ,
  'assignment idempotency is backed by claim/complete calls for assign_parcel_shipper'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) not like '%tracking_id%'
  ,
  'assignment command does not mutate or reinterpret parcel tracking ownership'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) not like '%orders.shipper_id%'
  ,
  'assignment command does not create an order-level courier source of truth'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%ShipperReassigned%'
  and pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%reassign_parcel_shipper%'
  ,
  'assignment function contains explicit reassignment behavior and audit action'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%Active courier is required%'
  ,
  'inactive couriers are blocked for new/different assignments'
);

select ok(
  pg_get_functiondef((
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'assign_parcel_shipper'
      and pg_get_function_identity_arguments(p.oid) =
        'p_parcel_id uuid, p_shipper_id uuid, p_idempotency_key text'
  )) like '%v_existing_shipper_id = p_shipper_id%'
  ,
  'same-target assignment is explicitly recognized as a no-op'
);

select * from finish();
rollback;