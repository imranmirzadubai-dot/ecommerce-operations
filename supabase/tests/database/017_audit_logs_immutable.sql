begin;

select plan(4);

select has_table('public', 'audit_logs', 'audit_logs table exists');
select has_trigger('public', 'audit_logs', 'trg_audit_logs_immutable', 'immutable audit trigger exists');
select policies_are('public', 'audit_logs', ARRAY[
  'audit_logs_authenticated_select'
], 'audit_logs has expected RLS policy');
select throws_ok(
  $$select public.prevent_audit_log_mutation()$$,
  '55000',
  'audit logs are immutable; append a new audit record instead',
  'mutation guard rejects direct invocation'
);

select * from finish();
rollback;
