import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')
const exporter = await readFile(new URL('../../src/components/OrderExport.tsx', import.meta.url), 'utf8')
const batch = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')
const reports = await readFile(new URL('../../src/components/ReportWorkspace.tsx', import.meta.url), 'utf8')
const reportFilters = await readFile(new URL('../../src/lib/reportFilters.ts', import.meta.url), 'utf8')

test('P6-T110 exports visible filtered orders as XLSX', () => {
  assert.match(exporter, /readVisibleRows/)
  assert.match(exporter, /Order.*Customer.*Phone.*Lifecycle State.*Amount \(AED\).*Order Date/s)
  assert.match(exporter, /downloadExcelWorkbook/)
  assert.match(exporter, /orders-export-/)
  assert.match(exporter, /selectedOrderIds/)
  assert.match(batch, /<OrderExport selectedOrderIds=\{selected\} accessToken=\{accessToken\} \/>/)
})

test('P6-T110 limits selected export to the current visible page', () => {
  assert.match(exporter, /selected\.size \? rows\.filter\(\(row\) => selected\.has\(row\.order\)\) : rows/)
})

test('P13-T204 mounts authenticated order export and reports in the active app shell', () => {
  assert.match(app, /import \{ OrderExport \} from '\.\/components\/OrderExport'/)
  assert.match(app, /<OrderExport selectedOrderIds=\{\[\]\} accessToken=\{auth\.accessToken\} \/>/)
  assert.match(app, /id="reports-title"/)
  assert.match(app, /onClick=\{\(\) => navigateTo\(item\)\}/)
})

test('P13-T204 exposes authenticated report views and Excel export', () => {
  for (const report of ['report_kpi_orders', 'report_kpi_parcels', 'report_kpi_delivery_outcomes', 'report_kpi_financial', 'report_kpi_imports', 'report_orders', 'report_parcel_delivery', 'report_customer_activity', 'report_cod_financial_reconciliation', 'report_historical_import_reconciliation', 'report_reconciliation_exceptions']) assert.match(reports, new RegExp(report))
  assert.match(reports, /Authorization: `Bearer \$\{accessToken\}`/)
  assert.match(reports, /downloadExcelWorkbook/)
  assert.match(reports, /Export Excel/)
  assert.match(reports, /authenticated read-only/i)
})

test('P13-T205 provides locked quick date views and custom date range controls', () => {
  for (const preset of ['All dates', 'Today', 'Yesterday', 'Last 7 days', 'Last 30 days', 'Custom']) assert.match(reports, new RegExp(preset))
  assert.match(reports, /Date from/)
  assert.match(reports, /Date to/)
  assert.match(reports, /type="date"/)
})

test('P13-T205 applies inclusive report-specific date filtering without inventing dates', () => {
  assert.match(reports, /filterRowsByDate/)
  assert.match(reportFilters, /if \(range\.from && key < range\.from\) return false/)
  assert.match(reportFilters, /if \(range\.to && key > range\.to\) return false/)
  assert.match(reports, /dateColumn: 'order_date'/)
  assert.match(reports, /dateColumn: 'dispatch_at'/)
  assert.match(reports, /dateColumn: 'latest_order_date'/)
  assert.match(reports, /dateColumn: 'started_at'/)
  assert.match(reports, /has no authoritative date column/)
})

test('P13-T205 uses deterministic calendar-day ranges for quick views', () => {
  assert.match(reportFilters, /resolveDatePreset/)
  assert.match(reportFilters, /preset === 'yesterday'/)
  assert.match(reportFilters, /preset === 'last7'/)
  assert.match(reportFilters, /preset === 'last30'/)
  assert.match(reportFilters, /start\.setDate\(start\.getDate\(\) - 6\)/)
  assert.match(reportFilters, /start\.setDate\(start\.getDate\(\) - 29\)/)
})

test('P13-T205 prevents inverted custom date ranges', () => {
  assert.match(reports, /Date from must be on or before Date to/)
  assert.match(reports, /dateRange\.from <= dateRange\.to/)
})
