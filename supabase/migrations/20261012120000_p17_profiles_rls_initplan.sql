begin;

-- Evaluate auth.uid() once per statement rather than once per candidate row.
-- Preserve the existing profile self-select authorization rule.
alter policy profiles_self_select
  on public.profiles
  using (id = (select auth.uid()));

commit;
