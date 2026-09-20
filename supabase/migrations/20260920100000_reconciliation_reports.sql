-- P13-T202: Reconciliation reports (RPT-04, RPT-05, RPT-06).
-- Read-only projections over authoritative COD, financial, import and exception data.

create or replace view public.report_cod_financial_reconciliation
with (security_invoker = true)
as
select
  o.id as order_id,
  o.order_number,
  p.id as parcel_id,
  p.parcel_number,
  p.shipper_id,
  co.id as cod_obligation_id,
  co.expected_amount as cod_obligation_amount,
  cr.id as cod_receipt_id,
  cr.received_amount as receipt_amount,
  cr.received_at,
  case when cr.id is null then null::numeric else cr.received_amount - cr.expected_amount_snapshot end as variance,
  coalesce(fa.adjustment_total, 0::numeric) as financial_adjustment_total,
  co.expected_amount + coalesce(fa.adjustment_total, 0::numeric) as effective_amount,
  case
    when cr.id is null then 'Uncollected'
    when cr.received_amount = cr.expected_amount_snapshot then 'Reconciled'
    else 'Variance'
  end as reconciliation_status,
  co.state as obligation_state,
  cr.state as receipt_state,
  o.created_at,
  o.updated_at
from public.cod_obligations co
join public.orders o on o.id = co.order_id
left join lateral (
  select r.*
  from public.cod_receipts r
  where r.cod_obligation_id = co.id
  order by r.received_at desc, r.id desc
  limit 1
) cr on true
left join lateral (
  select sum(a.delta_amount)::numeric as adjustment_total
  from public.financial_adjustments a
  where a.order_id = o.id
    and (cr.parcel_id is null or a.parcel_id = cr.parcel_id or a.parcel_id is null)
) fa on true
left join public.parcels p on p.id = cr.parcel_id;

create or replace view public.report_historical_import_reconciliation
with (security_invoker = true)
as
select
  b.id as batch_id,
  b.source_system,
  b.source_file,
  b.initiated_by,
  b.status as batch_status,
  b.started_at,
  b.completed_at,
  count(r.id)::integer as total_source_rows,
  count(r.id) filter (where r.status = 'Valid')::integer as valid_count,
  count(r.id) filter (where r.status in ('Error', 'Invalid'))::integer as error_count,
  coalesce((b.reconciliation_summary->>'create_count')::integer, 0) as create_count,
  coalesce((b.reconciliation_summary->>'matched_count')::integer, 0) as matched_count,
  coalesce((b.reconciliation_summary->>'exception_count')::integer, count(r.id) filter (where r.status in ('Error', 'Invalid'))::integer) as exception_count,
  coalesce((b.reconciliation_summary->>'source_row_count')::integer, count(r.id)::integer) as reconciled_source_row_count,
  coalesce((b.reconciliation_summary->'staging_reconciliation'->>'matched_count')::integer, 0) as reconciled_matched_count,
  coalesce((b.reconciliation_summary->'staging_reconciliation'->>'create_count')::integer, 0) as reconciled_create_count,
  coalesce((b.reconciliation_summary->'staging_reconciliation'->>'exception_count')::integer, 0) as reconciled_exception_count,
  coalesce((b.reconciliation_summary->'staging_reconciliation'->>'reconciled')::boolean, false) as staging_reconciled,
  coalesce((b.reconciliation_summary->'monetary_count_reconciliation'->>'reconciled')::boolean, false) as monetary_count_reconciled,
  coalesce((b.reconciliation_summary->>'error_report_available')::boolean, false) as error_report_available,
  case
    when coalesce((b.reconciliation_summary->'staging_reconciliation'->>'reconciled')::boolean, false)
     and coalesce((b.reconciliation_summary->'monetary_count_reconciliation'->>'reconciled')::boolean, false)
    then 'Reconciled'
    else 'Exception'
  end as reconciliation_result
from public.import_batches b
left join public.import_rows r on r.batch_id = b.id
group by b.id;

create or replace view public.report_reconciliation_exceptions
with (security_invoker = true)
as
select
  'Historical Import'::text as exception_category,
  'import_row'::text as entity_type,
  r.id as entity_id,
  r.batch_id,
  null::uuid as order_id,
  null::uuid as parcel_id,
  null::uuid as customer_id,
  r.source_row_number::text as entity_identifier,
  null::numeric as expected_value,
  null::numeric as actual_value,
  null::numeric as variance,
  'Open'::text as resolution_state,
  r.error as exception_detail,
  b.initiated_by as responsible_actor,
  b.source_system,
  b.source_file,
  null::timestamptz as created_at,
  null::timestamptz as updated_at
from public.import_rows r
join public.import_batches b on b.id = r.batch_id
where r.status in ('Error', 'Invalid')

union all

select
  'COD Variance'::text as exception_category,
  'cod_receipt'::text as entity_type,
  cr.id as entity_id,
  null::uuid as batch_id,
  co.order_id,
  cr.parcel_id,
  o.customer_id,
  coalesce(p.parcel_number, o.order_number) as entity_identifier,
  cr.expected_amount_snapshot as expected_value,
  cr.received_amount as actual_value,
  cr.received_amount - cr.expected_amount_snapshot as variance,
  'Open'::text as resolution_state,
  'COD receipt amount differs from immutable expected amount snapshot'::text as exception_detail,
  cr.received_by as responsible_actor,
  null::text as source_system,
  null::text as source_file,
  cr.received_at as created_at,
  cr.received_at as updated_at
from public.cod_receipts cr
join public.cod_obligations co on co.id = cr.cod_obligation_id
join public.orders o on o.id = co.order_id
left join public.parcels p on p.id = cr.parcel_id
where cr.received_amount <> cr.expected_amount_snapshot;

revoke all on public.report_cod_financial_reconciliation from public, anon;
revoke all on public.report_historical_import_reconciliation from public, anon;
revoke all on public.report_reconciliation_exceptions from public, anon;
grant select on public.report_cod_financial_reconciliation to authenticated;
grant select on public.report_historical_import_reconciliation to authenticated;
grant select on public.report_reconciliation_exceptions to authenticated;
