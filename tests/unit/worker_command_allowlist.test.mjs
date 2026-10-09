import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')
const commands = worker.match(/const ALLOWED_COMMANDS = new Set\(\[([\s\S]*?)\]\)/)?.[1] ?? ''

test('Worker allowlist includes the active parcel and financial RPC contracts', () => {
  for (const command of [
    'allocate_parcel_item',
    'allocate_parcel_items',
    'assign_parcel_shipper',
    'validate_unique_tracking_id',
    'create_financial_adjustment',
  ]) {
    assert.match(commands, new RegExp('"'+command+'"'), command+' must be allowed through the Worker')
  }
  assert.doesNotMatch(commands, /"record_financial_adjustment"/, 'stale financial RPC name must not remain allowlisted')
})
