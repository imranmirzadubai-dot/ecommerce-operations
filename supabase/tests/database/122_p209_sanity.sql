begin;
select plan(1);
select ok(exists (select 1 from pg_proc where proname='claim_command_idempotency'), 'P14-T209 idempotency command exists');
select * from finish();
rollback;
