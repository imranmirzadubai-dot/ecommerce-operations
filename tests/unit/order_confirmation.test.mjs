import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const migration = await readFile(new URL('../../supabase/migrations/20260913100000_order_confirmation.sql', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')

test('Draft orders expose a Confirm action', () => {
  assert.match(workspace, /handleConfirm\(order\)/)
  assert.match(workspace, /order\.lifecycle_state === 'Draft'/)
  assert.match(workspace, /Confirming…/)
  assert.match(workspace, /Order \$\{confirmed\.order_number\} confirmed\./)
})

test('confirmation uses the protected transactional command boundary', () => {
  assert.match(commands, /export type ConfirmOrderInput/)
  assert.match(commands, /export async function confirmOrder\(/)
  assert.match(commands, /'confirm_order'/)
  assert.match(workspace, /confirmOrder\(accessToken, \{ p_order_id: order\.id, p_idempotency_key: crypto\.randomUUID\(\) \}\)/)
  assert.match(worker, /"confirm_order"/)
})

test('confirmation is Draft-only, idempotent, audited and evented', () => {
  assert.match(migration, /drop function if exists public\.confirm_order\(uuid\)/)
  assert.match(migration, /if v_state <> 'Draft' then/)
  assert.match(migration, /claim_command_idempotency\('confirm_order'/)
  assert.match(migration, /complete_command_idempotency\('confirm_order'/)
  assert.match(migration, /'OrderConfirmed'/)
  assert.match(migration, /'confirm_order'/)
  assert.match(migration, /lifecycle_state='Confirmed'/)
})
