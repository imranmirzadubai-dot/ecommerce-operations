import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const source = await readFile(new URL('../../src/lib/parcelCommands.ts', import.meta.url), 'utf8')
test('P7-T116 exposes the parcel allocation command with typed inputs and results', () => {
  assert.match(source, /allocateParcelItem\(accessToken: string/)
  assert.match(source, /runCommand<AllocateParcelItemResult\[]>\('allocate_parcel_item'/)
  assert.match(source, /p_parcel_id: string/)
  assert.match(source, /p_order_item_id: string/)
  assert.match(source, /p_quantity: number/)
  assert.match(source, /p_idempotency_key: string/)
  assert.match(source, /allocation_state: string/)
})
