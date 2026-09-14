import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const migration = fs.readFileSync(
  new URL('../../supabase/migrations/20260914030000_invoice_historical_reprint_snapshot.sql', import.meta.url),
  'utf8',
)
const component = fs.readFileSync(
  new URL('../../src/components/InvoicePrintWorkspace.tsx', import.meta.url),
  'utf8',
)

test('invoice records capture a mandatory immutable historical source snapshot', () => {
  assert.match(migration, /add column if not exists source_snapshot jsonb/)
  assert.match(migration, /alter column source_snapshot set not null/)
  assert.match(migration, /Invoice historical snapshot is immutable/)
  assert.match(migration, /trg_invoice_record_historical_snapshot_immutable/)
})

test('new invoice records snapshot authoritative generation values', () => {
  assert.match(migration, /create or replace function public\.capture_invoice_historical_snapshot/)
  assert.match(migration, /before insert on public\.invoice_records/)
  assert.match(migration, /new\.source_snapshot := jsonb_build_object/)
  assert.match(migration, /exactly one parcel for the order/)
})

test('invoice printing renders from the historical snapshot rather than live order data', () => {
  assert.match(component, /source_snapshot: InvoiceSource/)
  assert.match(component, /select=.*source_snapshot/)
  assert.match(component, /record\.source_snapshot\.templateVersion !== record\.template_version/)
  assert.match(component, /renderInvoiceHtml\(source\)/)
  assert.doesNotMatch(component, /order\.parcels\.length !== 1/)
})
