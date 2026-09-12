-- P3-T052 — Profiles table and role model hardening
-- Preserve the locked v4.0 role contract: sales, operations, admin.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  name text not null,
  email text not null,
  role text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Reconcile an existing foundation deployment without replacing or duplicating constraints.
do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.profiles'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) = 'CHECK ((role = ANY (ARRAY[''sales''::text, ''operations''::text, ''admin''::text])))'
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('sales','operations','admin'));
  end if;
end;
$$;

alter table public.profiles
  alter column active set default true;

create or replace function public.app_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.active = true
$$;

revoke all on function public.app_role() from public;
grant execute on function public.app_role() to authenticated;

alter table public.profiles enable row level security;

-- Recreate the authoritative self-read policy only when absent.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_self_select'
  ) then
    create policy profiles_self_select
      on public.profiles
      for select
      to authenticated
      using (id = auth.uid());
  end if;
end;
$$;

-- Profiles are not a direct browser write surface. Role changes remain command-owned.
revoke all on public.profiles from anon;
revoke all on public.profiles from authenticated;
grant select on public.profiles to authenticated;
