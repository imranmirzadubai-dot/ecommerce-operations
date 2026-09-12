begin;

-- P4-T083: administrator-facing profile controls.
-- Admins may inspect profiles and use the existing controlled lifecycle/linking commands.
create policy profiles_admin_select on public.profiles
  for select to authenticated using (public.app_role() = 'admin');

commit;
