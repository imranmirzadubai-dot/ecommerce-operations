begin;

select plan(7);

select has_table('public', 'command_idempotency', 'command idempotency table exists');
select ok((select relrowsecurity from pg_class where oid='public.command_idempotency'::regclass), 'command idempotency has RLS enabled');
select has_function('public', 'claim_command_idempotency', ARRAY['text','text','text'], 'claim command idempotency function exists');
select has_function('public', 'complete_command_idempotency', ARRAY['text','text','jsonb'], 'complete command idempotency function exists');
select ok(has_table_privilege('authenticated','public.command_idempotency','select') = false, 'authenticated has no direct select access to idempotency ledger');
select ok(has_table_privilege('authenticated','public.command_idempotency','insert') = false, 'authenticated has no direct insert access to idempotency ledger');
select ok(has_table_privilege('authenticated','public.command_idempotency','update') = false, 'authenticated has no direct update access to idempotency ledger');

select * from finish();
rollback;
