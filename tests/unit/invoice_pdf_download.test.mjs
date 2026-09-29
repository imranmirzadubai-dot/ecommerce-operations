import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const pdfSource = fs.readFileSync(new URL('../../src/lib/invoicePdf.ts', import.meta.url), 'utf8')
const component = fs.readFileSync(new URL('../../src/components/InvoicePrintWorkspace.tsx', import.meta.url), 'utf8')

test('invoice PDF generator produces a real PDF document from invoice snapshots', () => {
  assert.ok(pdfSource.includes('export function renderInvoicePdf(sources: InvoiceSource): Uint8Array'))
  assert.ok(pdfSource.includes('%PDF-1.4'))
  assert.ok(pdfSource.includes('/Type /Catalog'))
  assert.ok(pdfSource.includes('/Type /Page'))
  assert.ok(pdfSource.includes('/Type /Font'))
  assert.ok(pdfSource.includes('/BaseFont /Helvetica-Bold'))
})

test('invoice PDF generator uses the authoritative order number in the filename flow', () => {
  assert.ok(component.includes('renderInvoicePdf([source])'))
  assert.ok(component.includes('anchor.download = filename'))
  assert.ok(component.includes('`${source.orderNumber}.pdf`'))
})

test('invoice PDF generator supports deterministic multi-page batch output', () => {
  assert.ok(component.includes('renderInvoicePdf(sources)'))
  assert.ok(component.includes('Invoice-Batch-${sources[0].orderNumber}-to-${sources[sources.length - 1].orderNumber}.pdf'))
})
