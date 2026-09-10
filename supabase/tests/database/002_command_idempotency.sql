begin;

select plan(4);

select has_table('public', 'command_idempotency', 'command idempotency table exists');
select ok((select relrowsecurity from pg_class where oid='public.command_idempotency'::regclass), 'command idempotency has RLS enabled');
select has_function('public', 'claim_command_idempotency', ARRAY['text','text','text'], 'claim command idempotency function exists');
select has_function('public', 'complete_command_idempotency', ARRAY['text','text','jsonb'], 'complete command idempotency function exists');

select * from finish();
rollback;
