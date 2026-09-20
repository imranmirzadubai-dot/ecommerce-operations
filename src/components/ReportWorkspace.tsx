import { useCallback, useEffect, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { downloadExcelWorkbook } from '../lib/excel'

type Props = { accessToken: string }
type Report = { name: string; title: string; columns: string[]; rows: Record<string, unknown>[] }

const REPORTS: Omit<Report, 'rows'>[] = [
  { name: 'report_kpi_orders', title: 'Order Summary', columns: ['lifecycle_state', 'order_count', 'original_amount_total'] },
  { name: 'report_kpi_parcels', title: 'Parcel Operations', columns: ['state', 'parcel_count'] },
  { name: 'report_kpi_delivery_outcomes', title: 'Delivery Outcomes', columns: ['outcome', 'outcome_count'] },
  { name: 'report_kpi_financial', title: 'COD & Financial Reconciliation', columns: ['cod_expected_total', 'cod_received_total', 'cod_variance_total', 'financial_adjustment_total'] },
  { name: 'report_kpi_imports', title: 'Historical Import Reconciliation', columns: ['batch_count', 'imported_row_count', 'failed_row_count'] },
  { name: 'report_orders', title: 'Orders Detail', columns: ['order_number', 'customer_name', 'city', 'original_amount', 'lifecycle_state', 'order_date'] },
  { name: 'report_parcel_delivery', title: 'Parcel & Delivery', columns: ['parcel_id', 'order_number', 'state', 'shipper_name', 'tracking_id', 'latest_outcome', 'delivered_amount'] },
  { name: 'report_customer_activity', title: 'Customer Activity', columns: ['customer_code', 'customer_name', 'normalized_phone', 'city', 'order_count', 'first_order_date', 'latest_order_date', 'original_amount_total', 'open_order_count'] },
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
    {reports.map((report) => <article className="report-card" key={report.name}><div className="section-heading"><div><strong>{report.title}</strong><span className="form-note">{report.rows.length} row{report.rows.length === 1 ? '' : 's'}</span></div><button className="secondary-button" type="button" onClick={() => exportReport(report)} disabled={!report.rows.length}>Export Excel</button></div><div className="report-table-wrap"><table className="report-table"><thead><tr>{report.columns.map((column) => <th key={column}>{column.replaceAll('_', ' ')}</th>)}</tr></thead><tbody>{report.rows.slice(0, 25).map((row, index) => <tr key={index}>{report.columns.map((column) => <td key={column}>{display(row[column])}</td>)}</tr>)}</tbody></table>{!report.rows.length && <p className="form-note">No rows returned for the current authenticated dataset.</p>}{report.rows.length > 25 && <p className="form-note">Showing the first 25 rows. Use the source report for the complete dataset.</p>}</div></article>)}
  </section>
}
