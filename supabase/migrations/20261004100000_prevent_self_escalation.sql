-- P17-T291: defense-in-depth protection against self privilege escalation.
-- A user must never be able to change their own application role or active status.
-- Existing trusted Admin commands already enforce this invariant; this trigger
-- provides a database-level guard against future mutation paths.

create or replace function public.prevent_self_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if v_actor is not null and v_actor = old.id then
    if new.role is distinct from old.role then
      raise exception using errcode = '42501', message = 'self_role_change_forbidden';
    end if;

    if new.active is distinct from old.active then
      raise exception using errcode = '42501', message = 'self_status_change_forbidden';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_self_privilege_escalation() from public;

drop trigger if exists profiles_prevent_self_privilege_escalation on public.profiles;

create trigger profiles_prevent_self_privilege_escalation
before update of role, active on public.profiles
for each row
execute function public.prevent_self_privilege_escalation();
