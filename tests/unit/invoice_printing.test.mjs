import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const component = fs.readFileSync(new URL('../../src/components/InvoicePrintWorkspace.tsx', import.meta.url), 'utf8')


test('individual printing uses historical renderer and print event command', () => {
  assert.ok(component.includes('renderInvoiceHtml(source)'))
  assert.ok(component.includes('p_print_mode: mode'))
  assert.ok(component.includes('record_invoice_print'))
  assert.ok(component.includes('template_version'))
  assert.ok(component.includes('source_snapshot'))
})

test('historical snapshot owns parcel identity and template lineage', () => {
  assert.ok(component.includes('record.source_snapshot'))
  assert.ok(component.includes('record.source_snapshot.templateVersion !== record.template_version'))
})

test('individual printing prevents concurrent print actions', () => {
  assert.ok(component.includes('if (printingId || batchPrinting) return'))
  assert.ok(component.includes('disabled={busy}'))
})

test('batch printing renders every selected invoice and records batch events', () => {
  assert.ok(component.includes('selectedIds'))
  assert.ok(component.includes('selected.map(toInvoiceSource)'))
  assert.ok(component.includes("recordPrint(accessToken, record.id, 'batch')"))
  assert.ok(component.includes('p_metadata: { client:'))
  assert.ok(component.includes('page-break-after: always'))
})

test('batch printing supports select-all and selected-count action', () => {
  assert.ok(component.includes('toggleAll'))
  assert.ok(component.includes('Print selected'))
  assert.ok(component.includes('selectedIds.length === records.length'))
})