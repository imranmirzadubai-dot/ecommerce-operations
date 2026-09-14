import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const source = fs.readFileSync(new URL('../../src/lib/invoice.ts', import.meta.url), 'utf8')

function cssRule(selector) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const match = source.match(new RegExp(`${escaped}\\s*\\{([\\s\\S]*?)\\}`))
  assert.ok(match, `${selector} rule must be present`)
  return match[1]
}

test('T135 uses explicit A4 print page sizing and controlled print margins', () => {
  assert.match(source, /@page\s*\{\s*size:\s*A4;\s*margin:\s*12mm;\s*\}/)
  assert.match(source, /\.invoice\s*\{[\s\S]*max-width:\s*190mm;/)
  assert.match(source, /@media print\s*\{[\s\S]*\.invoice\s*\{\s*max-width:\s*none;/)
})

test('T135 keeps barcode physically sized for a 1D invoice print area', () => {
  const barcodeRule = cssRule('.invoice-barcode-svg')
  assert.match(barcodeRule, /width:\s*72mm/)
  assert.match(barcodeRule, /height:\s*24mm/)
  assert.match(source, /shape-rendering="crispEdges"/)
  assert.match(source, /<svg class="invoice-barcode-svg"/)
})

test('T135 preserves print-critical invoice fields in the printable HTML contract', () => {
  for (const token of [
    'INVOICE',
    'Invoice No.',
    'Order ID',
    'Date',
    'Tracking ID',
    'Parcel Barcode',
    'Customer',
    'Items',
    'Total Order Amount',
    'Template ${escapeHtml(source.templateVersion)}',
    'Generated ${escapeHtml(source.generatedAt)}',
  ]) assert.match(source, new RegExp(token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
})

test('T135 uses print-safe white page/background and structured tabular layout', () => {
  const bodyRule = cssRule('body')
  const tableRule = cssRule('table')
  const cellRule = cssRule('th, td')
  assert.match(bodyRule, /margin:\s*0/)
  assert.match(bodyRule, /background:\s*#fff/)
  assert.match(tableRule, /width:\s*100%/)
  assert.match(tableRule, /border-collapse:\s*collapse/)
  assert.match(cellRule, /border-bottom:\s*1px solid #d5d5d5/)
})

test('T135 keeps invoice print output deterministic and free of screen-only dependencies', () => {
  assert.match(source, /export function renderInvoiceHtml\(source: InvoiceSource\): string/)
  assert.doesNotMatch(source, /window\.print\(\)/)
  assert.doesNotMatch(source, /@media screen/)
})
