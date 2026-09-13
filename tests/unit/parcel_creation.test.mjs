import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const parcelCommands = await readFile(new URL('../../src/lib/parcelCommands.ts', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')

test('P7-T113 exposes the authenticated create_parcel command contract', () => {
  assert.match(parcelCommands, /createParcel\(accessToken: string/)
  assert.match(parcelCommands, /runCommand<CreateParcelResult\[]>\('create_parcel'/)
  assert.match(parcelCommands, /p_order_id: string/)
  assert.match(parcelCommands, /p_idempotency_key: string/)
  assert.match(parcelCommands, /parcel_number: string/)
  assert.match(parcelCommands, /barcode: string/)
  assert.match(parcelCommands, /state: string/)
  assert.match(worker, /"create_parcel"/)
})
