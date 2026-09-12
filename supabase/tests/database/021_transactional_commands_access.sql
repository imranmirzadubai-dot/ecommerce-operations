begin;

select plan(12);

select has_function('public','create_order',ARRAY['text','text','text','text','numeric','jsonb','text','text'],'canonical create_order command exists');
select has_function('public','confirm_order',ARRAY['uuid','text'],'canonical confirm_order command exists');
select has_function('public','cancel_order',ARRAY['uuid','text'],'canonical cancel_order command exists');
select has_function('public','cancel_parcel',ARRAY['uuid','text'],'canonical cancel_parcel command exists');
select has_function('public','resolve_customer_by_phone',ARRAY['text'],'customer resolution command exists');
select has_function('public','claim_command_idempotency',ARRAY['text','text','text'],'idempotency claim helper exists');
select has_function('public','complete_command_idempotency',ARRAY['text','text','jsonb'],'idempotency completion helper exists');
select hasnt_function('public','create_order',ARRAY['text','text','text','text','numeric','jsonb','text'],'legacy create_order signature removed');
select hasnt_function('public','confirm_order',ARRAY['uuid'],'legacy confirm_order signature removed');
select hasnt_function('public','cancel_order',ARRAY['uuid'],'legacy cancel_order signature removed');
select ok((select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_order','confirm_order','cancel_order','cancel_parcel','resolve_customer_by_phone','claim_command_idempotency','complete_command_idempotency') and p.prosecdef), 'all transactional command functions are SECURITY DEFINER');
select ok((select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_order','confirm_order','cancel_order','cancel_parcel','resolve_customer_by_phone','claim_command_idempotency','complete_command_idempotency') and has_function_privilege('anon',p.oid,'EXECUTE')=false and has_function_privilege('authenticated',p.oid,'EXECUTE')), 'all transactional command functions are authenticated-only');

select * from finish();
rollback;
