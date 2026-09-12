import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')
const migration = await readFile(new URL('../../supabase/migrations/20260913090000_pre_confirmation_order_editing.sql', import.meta.url), 'utf8')

test('Draft orders expose an Edit action and editor fields', () => {
  assert.match(workspace, /order\.lifecycle_state === 'Draft'/)
  assert.match(workspace, /startEditing\(order\)/)
  assert.match(workspace, /Edit \{editing\.order_number\}/)
  assert.match(workspace, /Save Draft Changes/)
  assert.match(workspace, /p_order_id: editing\.id/)
  assert.match(workspace, /p_original_amount: normalizedAmount/)
  assert.match(workspace, /p_items: items/)
  assert.match(workspace, /p_notes: draft\.notes\.trim\(\) \|\| null/)
})

test('edit command uses the protected transactional update_order boundary', () => {
  assert.match(commands, /export type UpdateOrderInput/)
  assert.match(commands, /export async function updateOrder\(/)
  assert.match(commands, /'update_order'/)
  assert.match(workspace, /updateOrder\(accessToken, \{/)
  assert.match(worker, /"update_order"/)
})

test('editing is Draft-only and audited as an OrderUpdated event', () => {
  assert.match(migration, /if v_state <> 'Draft' then/)
  assert.match(migration, /Only Draft orders can be edited before confirmation/)
  assert.match(migration, /'OrderUpdated'/)
  assert.match(migration, /'update_order'/)
  assert.match(migration, /claim_command_idempotency\('update_order'/)
  assert.match(migration, /complete_command_idempotency\('update_order'/)
})
