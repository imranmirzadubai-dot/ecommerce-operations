-- P17-T293: database-level protection for the final active Admin.
-- The application commands already protect this invariant, but the invariant
-- must also hold for every future direct mutation path.
-- No update may transition the final active Admin to a non-active/non-Admin state.

create or replace function public.prevent_last_active_admin()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_other_active_admins bigint;
begin
  if old.role = 'admin'
     and old.active = true
     and (new.role is distinct from old.role or new.active is distinct from old.active)
     and not (new.role = 'admin' and new.active = true) then

    -- Serialize all privileged role/status transitions so concurrent updates
    -- cannot both observe the same final Admin and remove it simultaneously.
    perform pg_advisory_xact_lock(2147483002);

    select count(*)
      into v_other_active_admins
    from public.profiles p
    where p.id <> old.id
      and p.role = 'admin'
      and p.active = true;

    if v_other_active_admins = 0 then
      raise exception using
        errcode = '42501',
        message = 'last_active_admin_protected';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_last_active_admin() from public;

drop trigger if exists profiles_prevent_last_active_admin on public.profiles;

create trigger profiles_prevent_last_active_admin
before update of role, active on public.profiles
for each row
execute function public.prevent_last_active_admin();
