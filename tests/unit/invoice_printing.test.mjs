import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const component = fs.readFileSync(new URL('../../src/components/InvoicePrintWorkspace.tsx', import.meta.url), 'utf8')

test('individual printing uses authoritative renderer and print event command', () => {
  assert.ok(component.includes('renderInvoiceHtml(source)'))
  assert.ok(component.includes("p_print_mode: 'individual'"))
  assert.ok(component.includes('record_invoice_print'))
  assert.ok(component.includes('template_version'))
  assert.ok(component.includes('parcel_number'))
})

test('individual printing requires exactly one parcel', () => {
  assert.ok(component.includes('order.parcels.length !== 1'))
  assert.ok(component.includes('exactly one parcel for the order'))
})

test('individual printing prevents concurrent print actions', () => {
  assert.ok(component.includes('if (printingId) return'))
  assert.ok(component.includes('disabled={printingId !== null}'))
})
