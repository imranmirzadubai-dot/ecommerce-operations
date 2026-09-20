import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')
const exporter = await readFile(new URL('../../src/components/OrderExport.tsx', import.meta.url), 'utf8')
const batch = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')
const reports = await readFile(new URL('../../src/components/ReportWorkspace.tsx', import.meta.url), 'utf8')

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
