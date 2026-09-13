import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const source = fs.readFileSync(new URL('../../src/lib/invoice.ts', import.meta.url), 'utf8')

test('invoice renderer accepts authoritative order and customer values', () => {
  assert.match(source, /export type InvoiceSource/)
  assert.match(source, /invoiceNumber: string/)
  assert.match(source, /orderNumber: string/)
  assert.match(source, /parcelNumber: string/)
  assert.match(source, /templateVersion: string/)
  assert.match(source, /orderDate: string/)
  assert.match(source, /currencyCode: 'AED'/)
  assert.match(source, /originalAmount: number/)
  assert.match(source, /customer: InvoiceCustomer/)
  assert.match(source, /items: InvoiceItem\[\]/)
  assert.match(source, /trackingId\?: string \| null/)
})

test('invoice renderer preserves the MVP commercial model', () => {
  assert.match(source, /Total Order Amount/)
  assert.match(source, /does not calculate or invent commercial fields/)
  assert.doesNotMatch(source, /serviceFee|discount|vatAmount|unitPrice/)
  assert.match(source, /Number\.isInteger\(item\.quantity\)/)
  assert.match(source, /Invoice must contain at least one order item/)
})

test('invoice renderer escapes untrusted printable values', () => {
  assert.match(source, /function escapeHtml/)
  assert.match(source, /\.replace\(\/&\/g, '&amp;'\)/)
  assert.match(source, /escapeHtml\(source\.customer\.name\)/)
  assert.match(source, /escapeHtml\(item\.description\)/)
  assert.match(source, /escapeHtml\(source\.invoiceNumber\)/)
  assert.match(source, /escapeHtml\(source\.orderNumber\)/)
  assert.match(source, /escapeHtml\(value\)/)
})

test('invoice renderer includes the authoritative Order ID', () => {
  assert.match(source, /Order ID<\/span>/)
  assert.match(source, /escapeHtml\(source\.orderNumber\)/)
})

test('invoice renderer includes a deterministic Code 128 parcel barcode', () => {
  assert.match(source, /CODE128_PATTERNS/)
  assert.match(source, /const checksum = \(104 \+ codeValues\.reduce/)
  assert.match(source, /symbols = \[104, \.\.\.codeValues, checksum, 106\]/)
  assert.match(source, /Parcel Barcode/)
  assert.match(source, /renderCode128Barcode\(requiredText\(source\.parcelNumber, 'Parcel number'\)\)/)
  assert.match(source, /invoice-barcode-svg/)
})

test('invoice renderer validates parcel barcode input', () => {
  assert.match(source, /requiredText\(source\.parcelNumber, 'Parcel number'\)/)
  assert.match(source, /Parcel number must contain printable ASCII characters/)
})

test('invoice renderer produces a print-oriented document', () => {
  assert.match(source, /@page \{ size: A4;/)
  assert.match(source, /renderInvoiceHtml/)
  assert.match(source, /data-template-version=/)
})
