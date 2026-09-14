import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const source = fs.readFileSync(new URL('../../src/lib/invoice.ts', import.meta.url), 'utf8')
const rendererMatch = source.match(/export function renderInvoiceHtml\(source: InvoiceSource\): string \{([\s\S]*)\n\}/)
assert.ok(rendererMatch, 'renderInvoiceHtml implementation must be present')

const renderInvoiceHtml = new Function('escapeHtml', rendererMatch[1])
const escapeHtml = (value) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;')

const sourceRecord = {
  invoiceNumber: 'INV-T135-001',
  orderNumber: 'ORD-T135-001',
  parcelNumber: 'PCL-T135-001',
  templateVersion: 'v1.0',
  generatedAt: '2026-09-14T13:00:00Z',
  orderDate: '2026-09-14',
  currencyCode: 'AED',
  originalAmount: 149.5,
  customer: { name: 'Print Workflow Customer', phone: '+971500000000', address: 'Printer Test Address', city: 'Dubai' },
  items: [{ lineNo: 1, description: 'Physical print workflow test item', quantity: 2 }],
  trackingId: 'TRK-T135-001',
}

function render() {
  return renderInvoiceHtml(escapeHtml, sourceRecord)
}

test('T135 uses explicit A4 print page sizing and controlled print margins', () => {
  const html = render()
  assert.match(html, /@page\s*\{\s*size:\s*A4;\s*margin:\s*12mm;\s*\}/)
  assert.match(html, /\.invoice\s*\{[\s\S]*max-width:\s*190mm;/)
  assert.match(html, /@media print\s*\{[\s\S]*\.invoice\s*\{\s*max-width:\s*none;/)
})

test('T135 keeps barcode physically sized for a 1D invoice print area', () => {
  const html = render()
  assert.match(html, /\.invoice-barcode-svg\s*\{[\s\S]*width:\s*72mm;\s*height:\s*24mm;/)
  assert.match(html, /shape-rendering="crispEdges"/)
  assert.match(html, /<svg class="invoice-barcode-svg"/)
})

test('T135 preserves print-critical invoice fields in the generated document', () => {
  const html = render()
  for (const value of ['INVOICE', 'INV-T135-001', 'ORD-T135-001', '2026-09-14', 'TRK-T135-001', 'PCL-T135-001', 'Print Workflow Customer', 'Physical print workflow test item', 'AED 149.50']) {
    assert.match(html, new RegExp(value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  }
  assert.match(html, /data-template-version="v1\.0"/)
  assert.match(html, /Template v1\.0 · Generated 2026-09-14T13:00:00Z/)
})

test('T135 uses print-safe white page/background and crisp table structure', () => {
  const html = render()
  assert.match(html, /body\s*\{[\s\S]*background:\s*#fff;/)
  assert.match(html, /table\s*\{[\s\S]*border-collapse:\s*collapse;/)
  assert.match(html, /th, td\s*\{[\s\S]*border-bottom:\s*1px solid #d5d5d5;/)
})

test('T135 is deterministic for the same printable source', () => {
  assert.equal(render(), render())
})
