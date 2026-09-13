import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')

test('P6-T111 provides order detail navigation from the order list', () => {
  assert.match(workspace, /Order Detail/)
  assert.match(workspace, /Open order detail/)
  assert.match(workspace, /setDetailOrder\(order\)/)
  assert.match(workspace, /Back to Orders/)
  assert.match(workspace, /Customer/)
  assert.match(workspace, /Phone/)
  assert.match(workspace, /Address/)
  assert.match(workspace, /Order items/)
  assert.match(workspace, /Open Timeline/)
})

test('P6-T111 exposes draft editing from order detail and keeps the selected order context', () => {
  assert.match(workspace, /detailOrder\.lifecycle_state === 'Draft'/)
  assert.match(workspace, /startEditing\(detailOrder\)/)
  assert.match(workspace, /detailOrder\.order_number/)
  assert.match(workspace, /detailOrder\.customers\?\.name/)
})
