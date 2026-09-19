-- P13-T200: Implement KPI summary queries/views.
-- Reporting is read-only and derives every KPI from authoritative domain tables.
-- No report view maintains competing business state.

create or replace view public.report_kpi_orders
with (security_invoker = true)
as
select
  o.lifecycle_state,
  count(*)::bigint as order_count,
  coalesce(sum(o.original_amount), 0::numeric(12,2)) as original_amount_total
from public.orders o
group by o.lifecycle_state;

create or replace view public.report_kpi_parcels
with (security_invoker = true)
as
select
  p.state as parcel_state,
  count(*)::bigint as parcel_count
from public.parcels p
group by p.state;

create or replace view public.report_kpi_delivery_outcomes
with (security_invoker = true)
as
select
  d.outcome,
  count(*)::bigint as outcome_count
from public.delivery_outcomes d
group by d.outcome;

create or replace view public.report_kpi_financial
with (security_invoker = true)
as
select
  coalesce((select sum(expected_amount) from public.cod_obligations), 0::numeric(12,2)) as cod_obligation_total,
  coalesce((select sum(received_amount) from public.cod_receipts), 0::numeric(12,2)) as cod_receipt_total,
  coalesce((select sum(received_amount - expected_amount_snapshot) from public.cod_receipts), 0::numeric(12,2)) as cod_variance_total,
  coalesce((select sum(delta_amount) from public.financial_adjustments), 0::numeric(12,2)) as financial_adjustment_total;

create or replace view public.report_kpi_imports
with (security_invoker = true)
as
select
  coalesce(sum((s.reconciliation_summary->>'row_count')::bigint), 0)::bigint as source_row_total,
  coalesce(sum((s.reconciliation_summary->>'matched_count')::bigint), 0)::bigint as matched_row_total,
  coalesce(sum((s.reconciliation_summary->>'create_count')::bigint), 0)::bigint as create_row_total,
  coalesce(sum((s.reconciliation_summary->>'exception_count')::bigint), 0)::bigint as exception_row_total,
  coalesce(sum((s.reconciliation_summary->>'unclassified_count')::bigint), 0)::bigint as unclassified_row_total,
  coalesce(sum((s.reconciliation_summary->>'status_mismatch_count')::bigint), 0)::bigint as status_mismatch_row_total,
  count(*) filter (where (s.reconciliation_summary->>'reconciled')::boolean is true)::bigint as reconciled_batch_count,
  count(*) filter (where (s.reconciliation_summary is not null))::bigint as reconciled_batch_summary_count,
  count(*)::bigint as import_batch_count
from public.import_batches s;

revoke all on public.report_kpi_orders, public.report_kpi_parcels,
  public.report_kpi_delivery_outcomes, public.report_kpi_financial,
  public.report_kpi_imports from anon;
grant select on public.report_kpi_orders, public.report_kpi_parcels,
  public.report_kpi_delivery_outcomes, public.report_kpi_financial,
  public.report_kpi_imports to authenticated;
