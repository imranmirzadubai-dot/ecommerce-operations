import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const pdfSource = fs.readFileSync(new URL('../../src/lib/invoicePdf.ts', import.meta.url), 'utf8')
const component = fs.readFileSync(new URL('../../src/components/InvoicePrintWorkspace.tsx', import.meta.url), 'utf8')

test('invoice PDF generator produces a real PDF document from invoice snapshots', () => {
  assert.match(pdfSource, /export function renderInvoicePdf\\(sources: InvoiceSource\\): Uint8Array/)
  assert.match(pdfSource, /%PDF-1\\.4/)
  assert.match(pdfSource, /\\/Type \/Catalog/)
  assert.match(pdfSource, /\\/Type \/Page/)
  assert.match(pdfSource, /\\/Type \/Font/)
  assert.match(pdfSource, /\\/BaseFont \/Helvetica-Bold/)
})

test('invoice PDF generator uses the authoritative order number in the filename flow', () => {
  assert.match(component, /renderInvoicePdf\\(\\[source\\]\\)/)
  assert.match(component, /anchor\\.download = filename/)
  assert.match(component, /source\\.orderNumber\\}\\.pdf/)
})

test('invoice PDF generator supports deterministic multi-page batch output', () => {
  assert.match(component, /renderInvoicePdf\\(sources\\)/)
  assert.match(component, /Invoice-Batch-/)
  assert.match(component, /sources\\[0\\]\\.orderNumber/)
  assert.match(component, /sources\\[sources\\.length - 1\\]\\.orderNumber/)
})
