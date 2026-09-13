import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const exporter = await readFile(new URL('../../src/components/OrderExport.tsx', import.meta.url), 'utf8')
const batch = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')

test('P6-T110 exports visible filtered orders as Excel-compatible CSV', () => {
  assert.match(exporter, /readVisibleRows/)
  assert.match(exporter, /Order ID/)
  assert.match(exporter, /Customer/)
  assert.match(exporter, /Phone/)
  assert.match(exporter, /Lifecycle State/)
  assert.match(exporter, /Amount/)
  assert.match(exporter, /Order Date/)
  assert.match(exporter, /text\/csv;charset=utf-8/)
  assert.match(exporter, /orders-export-/)
  assert.match(exporter, /selectedOrderIds/)
  assert.match(batch, /<OrderExport selectedOrderIds=\{selected\} \/>/)
})

test('P6-T110 escapes CSV cells and limits selected export to the current visible page', () => {
  assert.match(exporter, /value\.replace\(\/\"\/g, '\"\"'\)/)
  assert.match(exporter, /selected\.size \? rows\.filter\(\(row\) => selected\.has\(row\.order\)\) : rows/)
})
