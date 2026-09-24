import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const selection = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')
const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')

test('P6-T108 provides page-scoped batch order selection', () => {
  assert.match(selection, /Batch Selection/)
  assert.match(selection, /selected/)
  assert.match(selection, /visibleOrders/)
  assert.match(selection, /type="checkbox"/)
  assert.match(selection, /Select visible/)
  assert.match(selection, /Clear selection/)
  assert.match(selection, /Selection is scoped to the currently visible Orders workspace page/)
})

test('P6-T108 keeps the canonical Orders workspace as the active implementation', () => {
  assert.match(workspace, /export function OrdersWorkspace/)
  assert.doesNotMatch(workspace, /OrderBatchSelection as OrdersWorkspace/)
})

test('UI-002 removes temporary DOM observation from batch selection', () => {
  assert.match(selection, /OrderListRow/)
  assert.match(selection, /onOrdersChange={handleOrdersChange}/)
  assert.doesNotMatch(selection, /MutationObserver/)
  assert.doesNotMatch(selection, /querySelectorAll/)
  assert.doesNotMatch(selection, /document\.querySelector/)
})
