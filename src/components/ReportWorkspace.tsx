import { useCallback, useEffect, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { downloadExcelWorkbook } from '../lib/excel'

type Props = { accessToken: string }
type Report = { name: string; title: string; columns: string[]; rows: Record<string, unknown>[] }

const REPORTS: Omit<Report, 'rows'>[] = [
  { name: 'report_kpi_orders', title: 'Order Summary', columns: ['lifecycle_state', 'order_count', 'original_amount_total'] },
  { name: 'report_kpi_parcels', title: 'Parcel Operations', columns: ['parcel_state', 'parcel_count'] },
  { name: 'report_kpi_delivery_outcomes', title: 'Delivery Outcomes', columns: ['outcome', 'outcome_count'] },
  { name: 'report_kpi_financial', title: 'COD & Financial Reconciliation', columns: ['cod_obligation_total', 'cod_receipt_total', 'cod_variance_total', 'financial_adjustment_total'] },
  { name: 'report_kpi_imports', title: 'Historical Import Reconciliation', columns: ['source_row_total', 'matched_row_total', 'create_row_total', 'exception_row_total', 'unclassified_row_total', 'status_mismatch_row_total', 'reconciled_batch_count', 'reconciled_batch_summary_count', 'import_batch_count'] },
  { name: 'report_orders', title: 'Orders Detail', columns: ['order_number', 'customer_name', 'city', 'currency_code', 'original_amount', 'lifecycle_state', 'order_date'] },
  { name: 'report_parcel_delivery', title: 'Parcel & Delivery', columns: ['parcel_number', 'order_number', 'parcel_state', 'shipper_name', 'tracking_id', 'dispatch_at', 'latest_outcome', 'latest_outcome_at', 'delivered_amount', 'collected_at'] },
  { name: 'report_customer_activity', title: 'Customer Activity', columns: ['customer_code', 'customer_name', 'normalized_phone', 'city', 'order_count', 'first_order_date', 'latest_order_date', 'original_order_amount_total', 'current_open_order_count'] },
  { name: 'report_cod_financial_reconciliation', title: 'COD & Financial Reconciliation Detail', columns: ['order_number', 'parcel_number', 'cod_obligation_amount', 'receipt_amount', 'variance', 'financial_adjustment_total', 'effective_amount', 'reconciliation_status', 'obligation_state', 'receipt_state'] },
  { name: 'report_historical_import_reconciliation', title: 'Historical Import Reconciliation Detail', columns: ['source_system', 'source_file', 'batch_status', 'started_at', 'completed_at', 'total_source_rows', 'valid_count', 'error_count', 'create_count', 'matched_count', 'exception_count', 'reconciliation_result'] },
  { name: 'report_reconciliation_exceptions', title: 'Reconciliation Exceptions', columns: ['exception_category', 'entity_type', 'entity_identifier', 'expected_value', 'actual_value', 'variance', 'resolution_state', 'exception_detail', 'responsible_actor', 'source_system', 'source_file'] },
]

async function readReport(accessToken: string, report: Omit<Report, 'rows'>): Promise<Record<string, unknown>[]> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this deployment')
  const select = report.columns.join(',')
  const response = await fetch(`${config.url}/rest/v1/${report.name}?select=${encodeURIComponent(select)}`, {
    headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) throw new Error((payload as { message?: string } | null)?.message ?? `Report request failed (${response.status})`)
  return Array.isArray(payload) ? payload as Record<string, unknown>[] : []
}

function display(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'number') return value.toLocaleString()
  return String(value)
}

export function ReportWorkspace({ accessToken }: Props) {
  const [reports, setReports] = useState<Report[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true); setError('')
    try {
      const loaded = await Promise.all(REPORTS.map(async (report) => ({ ...report, rows: await readReport(accessToken, report) })))
      setReports(loaded)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Unable to load reports')
    } finally { setLoading(false) }
  }, [accessToken])

  useEffect(() => { void load() }, [load])

  function exportReport(report: Report) {
    const rows = [report.columns, ...report.rows.map((row) => report.columns.map((column) => display(row[column])))]
    downloadExcelWorkbook(`report-${report.name}-${new Date().toISOString().slice(0, 10)}.xlsx`, [{ name: report.title.slice(0, 31), rows }])
  }

  return <section className="card report-workspace" aria-label="Reports">
    <div className="section-heading"><div><span className="eyebrow">Reports</span><h2>Operational Reports</h2><p>Authenticated read-only reporting from the authoritative Phase 13 report views.</p></div><button className="secondary-button" type="button" onClick={() => void load()} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh reports'}</button></div>
    {error && <p className="form-error" role="alert">{error}</p>}
    {reports.map((report) => <article className="report-card" key={report.name}><div className="section-heading"><div><strong>{report.title}</strong><span className="form-note">{report.rows.length} row{report.rows.length === 1 ? '' : 's'}</span></div><button className="secondary-button" type="button" onClick={() => exportReport(report)} disabled={!report.rows.length}>Export Excel</button></div><div className="report-table-wrap"><table className="report-table"><thead><tr>{report.columns.map((column) => <th key={column}>{column.replaceAll('_', ' ')}</th>)}</tr></thead><tbody>{report.rows.slice(0, 25).map((row, index) => <tr key={index}>{report.columns.map((column) => <td key={column}>{display(row[column])}</td>)}</tr>)}</tbody></table>{!report.rows.length && <p className="form-note">No rows returned for the current authenticated dataset.</p>}{report.rows.length > 25 && <p className="form-note">Showing the first 25 rows. Export includes the complete returned dataset.</p>}</div></article>)}
  </section>
}
