begin;

-- T060: harden the COD obligation contract already introduced by the
-- database foundation. The obligation is one-per-order, exact AED money,
-- and its lifecycle is constrained to the approved state vocabulary.

alter table public.cod_obligations
  alter column expected_amount type numeric(12,2);

alter table public.cod_obligations
  drop constraint if exists cod_obligations_expected_amount_check;
alter table public.cod_obligations
  add constraint cod_obligations_expected_amount_check
  check (expected_amount >= 0);

alter table public.cod_obligations
  drop constraint if exists cod_obligations_state_check;
alter table public.cod_obligations
  add constraint cod_obligations_state_check
  check (state in ('Outstanding','Partially Received','Received','Exception','Voided','Closed'));

alter table public.cod_obligations
  drop constraint if exists cod_obligations_order_id_key;
alter table public.cod_obligations
  add constraint cod_obligations_order_id_key unique (order_id);

alter table public.cod_obligations enable row level security;
revoke all on public.cod_obligations from anon;
revoke all on public.cod_obligations from authenticated;
grant select on public.cod_obligations to authenticated;

commit;
