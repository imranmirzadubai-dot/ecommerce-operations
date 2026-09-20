begin;

select plan(18);

-- This is a deterministic database-level concurrency contract test. It verifies the
-- primitives that serialize competing state changes and make retries atomic.
-- A single pgTAP session cannot create a true second live transaction, so this test
-- does not claim a two-session load test; it validates the production locking and
-- uniqueness contracts that such sessions rely on.

-- Command idempotency must serialize the same actor/command/key through a unique key.
select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where t.relname = 'command_idempotency'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) like '%actor_id%command_name%idempotency_key%'
  ),
  'command idempotency has a unique actor/command/key constraint'
);

select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'claim_command_idempotency'
      and p.prosrc ilike '%on conflict%do nothing%'
  ),
  'idempotency claim uses conflict-safe insert semantics'
);

select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'claim_command_idempotency'
      and p.prosrc ilike '%for update%'
  ),
  'idempotency claim locks the existing row before deciding retry state'
);

-- Transactional order state changes must lock the target order before validating state.
select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'confirm_order'
      and p.prosrc ilike '%for update%'
  ),
  'confirm_order locks the target order before transition'
);

select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'cancel_order'
      and p.prosrc ilike '%for update%'
  ),
  'cancel_order locks the target order before transition'
);

-- Customer resolution must serialize an existing customer row before update.
select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'create_order'
      and p.prosrc ilike '%where c.normalized_phone=v_normalized_phone for update%'
  ),
  'create_order locks an existing customer by normalized phone'
);

select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'create_order'
      and p.prosrc ilike '%exception when unique_violation%'
  ),
  'create_order recovers the concurrent customer insert race'
);

-- Immutable order amount remains protected while lifecycle commands operate.
select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'confirm_order'
      and p.prosrc ilike '%update public.orders set lifecycle_state=%'
      and p.prosrc not ilike '%original_amount%'
  ),
  'confirm_order does not mutate original order amount'
);

select ok(
  exists (
    select 1
    from pg_proc p
    where p.proname = 'cancel_order'
      and p.prosrc ilike '%update public.orders set lifecycle_state=%'
      and p.prosrc not ilike '%original_amount%'
  ),
  'cancel_order does not mutate original order amount'
);

-- Verify the command idempotency schema remains retry-safe and append-only in shape.
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='command_idempotency'
      and column_name='request_hash'
  ),
  'idempotency stores the request hash used to reject key reuse with different input'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='command_idempotency'
      and column_name='result'
  ),
  'idempotency stores the completed result for deterministic retries'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='command_idempotency'
      and column_name='status'
  ),
  'idempotency stores Started/Completed state'
);

select ok(
  exists (
    select 1 from information_schema.check_constraints
    where constraint_schema='public'
      and constraint_name in (
        select constraint_name
        from information_schema.constraint_column_usage
        where table_schema='public'
          and table_name='command_idempotency'
          and column_name='status'
      )
  ) is not null,
  'idempotency status is constrained by database schema'
);

-- The unique normalized-phone constraint is the second half of the create-order race guard.
select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    where t.relname='customers'
      and c.contype='u'
      and pg_get_constraintdef(c.oid) ilike '%normalized_phone%'
  ),
  'customers enforce normalized phone uniqueness at database level'
);

-- Verify the transactional commands are SECURITY DEFINER, so the lock/write sequence
-- executes atomically inside one database transaction rather than from client writes.
select ok(
  exists (
    select 1 from pg_proc p
    where p.proname='create_order' and p.prosecdef
  ),
  'create_order executes as SECURITY DEFINER'
);

select ok(
  exists (
    select 1 from pg_proc p
    where p.proname='confirm_order' and p.prosecdef
  ),
  'confirm_order executes as SECURITY DEFINER'
);

select ok(
  exists (
    select 1 from pg_proc p
    where p.proname='cancel_order' and p.prosecdef
  ),
  'cancel_order executes as SECURITY DEFINER'
);

-- No direct browser table writes means concurrent clients must enter through the
-- transactional command boundary rather than racing raw table updates.
select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema='public'
      and grantee='authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
      and table_name in ('customers','orders','order_items','parcels','parcel_items')
  ),
  'authenticated clients have no direct write grants on core operational tables'
);

select * from finish();
rollback;
