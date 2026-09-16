-- P10-T149: NDR is an operational, non-terminal parcel state.
-- Terminal classification is centralized so later NDR follow-up commands cannot
-- accidentally treat NDR as terminal.

create or replace function public.is_terminal_parcel_state(p_state text)
returns boolean
language sql
immutable
strict
security invoker
set search_path=pg_catalog, public
as $$
  select p_state in ('Delivered','RTO','Lost','Damaged','Cancelled');
$$;

revoke all on function public.is_terminal_parcel_state(text) from public;
grant execute on function public.is_terminal_parcel_state(text) to authenticated;

comment on function public.is_terminal_parcel_state(text) is
  'Returns true only for terminal parcel states. NDR is intentionally non-terminal and may continue through a later delivery outcome transition.';
