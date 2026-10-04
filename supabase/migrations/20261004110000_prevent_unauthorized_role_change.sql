-- P17-T292: defense-in-depth protection against unauthorized role changes.
-- Role changes must remain inside the trusted Admin authorization boundary.
-- T287 protects the dedicated role-change command; this trigger protects
-- future or accidental direct mutation paths at the database layer.

create or replace function public.prevent_unauthorized_role_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if new.role is distinct from old.role
     and v_actor is not null
     and public.app_role() <> 'admin' then
    raise exception using errcode = '42501', message = 'unauthorized_role_change';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_unauthorized_role_change() from public;

drop trigger if exists profiles_prevent_unauthorized_role_change on public.profiles;

create trigger profiles_prevent_unauthorized_role_change
before update of role on public.profiles
for each row
execute function public.prevent_unauthorized_role_change();
