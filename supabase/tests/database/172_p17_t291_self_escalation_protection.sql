-- P17-T291: self-escalation trigger contract.
begin;

select plan(5);

select ok((
  select count(*) = 1
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and t.tgname = 'profiles_prevent_self_escalation'
    and not t.tgisinternal
), 'profiles has the self-escalation trigger');

select ok((
  select pg_get_triggerdef(t.oid) ilike '%BEFORE UPDATE OF role, active%'
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and t.tgname = 'profiles_prevent_self_escalation'
), 'trigger covers role and active changes');

select ok((
  select p.prosecdef
    and pg_get_functiondef(p.oid) ilike '%set search_path = pg_catalog, public%'
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'prevent_profile_self_escalation'
), 'trigger function is SECURITY DEFINER with pinned search_path');

select ok((
  select pg_get_functiondef(p.oid) ilike '%old.id = v_actor%'
     and pg_get_functiondef(p.oid) ilike '%new.role is distinct from old.role%'
     and pg_get_functiondef(p.oid) ilike '%new.active is distinct from old.active%'
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'prevent_profile_self_escalation'
), 'trigger blocks own role or active-state changes');

select ok((
  select not has_function_privilege('anon', p.oid, 'EXECUTE')
     and not has_function_privilege('authenticated', p.oid, 'EXECUTE')
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'prevent_profile_self_escalation'
), 'trigger function is not directly executable by API roles');

select * from finish();
rollback;
