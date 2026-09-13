import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const selection = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')
const router = await readFile(new URL('../../src/components/OrdersWorkspace.ts', import.meta.url), 'utf8')

test('P6-T108 provides page-scoped batch order selection', () => {
  assert.match(selection, /Batch Selection/)
  assert.match(selection, /selected/)
  assert.match(selection, /visibleOrders/)
  assert.match(selection, /type="checkbox"/)
  assert.match(selection, /Select visible/)
  assert.match(selection, /Clear selection/)
  assert.match(selection, /Selection is scoped to the currently visible Orders workspace page/)
})

test('P6-T108 routes the authenticated Orders workspace through batch selection', () => {
  assert.match(router, /OrderBatchSelection as OrdersWorkspace/)
})
