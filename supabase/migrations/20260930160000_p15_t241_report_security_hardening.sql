-- P15-T241: harden report views to respect application RLS and least-privilege grants.
-- Report views are read-only application surfaces. They must not expose a
-- SECURITY DEFINER-style owner bypass of underlying RLS policies.

begin;

revoke all on table
  public.report_cod_financial_reconciliation,
  public.report_customer_activity,
  public.report_historical_import_reconciliation,
  public.report_kpi_delivery_outcomes,
  public.report_kpi_financial,
  public.report_kpi_imports,
  public.report_kpi_orders,
  public.report_kpi_parcels,
  public.report_orders,
  public.report_parcel_delivery,
  public.report_reconciliation_exceptions
from authenticated;

grant select on table
  public.report_cod_financial_reconciliation,
  public.report_customer_activity,
  public.report_historical_import_reconciliation,
  public.report_kpi_delivery_outcomes,
  public.report_kpi_financial,
  public.report_kpi_imports,
  public.report_kpi_orders,
  public.report_kpi_parcels,
  public.report_orders,
  public.report_parcel_delivery,
  public.report_reconciliation_exceptions
to authenticated;

-- PostgreSQL views otherwise execute with the view owner's privileges.
-- SECURITY INVOKER makes the underlying table RLS/object permissions apply
-- to the calling authenticated user.
alter view public.report_cod_financial_reconciliation set (security_invoker = true);
alter view public.report_customer_activity set (security_invoker = true);
alter view public.report_historical_import_reconciliation set (security_invoker = true);
alter view public.report_kpi_delivery_outcomes set (security_invoker = true);
alter view public.report_kpi_financial set (security_invoker = true);
alter view public.report_kpi_imports set (security_invoker = true);
alter view public.report_kpi_orders set (security_invoker = true);
alter view public.report_kpi_parcels set (security_invoker = true);
alter view public.report_orders set (security_invoker = true);
alter view public.report_parcel_delivery set (security_invoker = true);
alter view public.report_reconciliation_exceptions set (security_invoker = true);

commit;
