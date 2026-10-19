-- P17-T291: prevent users from changing their own privileged profile state.
-- Defense in depth: T287/T288 remain the trusted command boundaries.
-- No production data is changed by creating or testing this migration.

create or replace function public.prevent_profile_self_escalation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if v_actor is not null
     and old.id = v_actor
     and (
       new.role is distinct from old.role
       or new.active is distinct from old.active
     ) then
    raise exception using errcode = '42501', message = 'profile_self_escalation_forbidden';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_profile_self_escalation() from public, anon, authenticated;

drop trigger if exists profiles_prevent_self_escalation on public.profiles;

create trigger profiles_prevent_self_escalation
before update of role, active on public.profiles
for each row
execute function public.prevent_profile_self_escalation();
