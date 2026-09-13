import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const indicator = await readFile(new URL('../../src/components/OperationalStatusIndicators.tsx', import.meta.url), 'utf8')
const selection = await readFile(new URL('../../src/components/OrderBatchSelection.tsx', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')

test('P6-T109 exposes lifecycle, parcel and COD operational indicators', () => {
  assert.match(indicator, /Operational status indicators/)
  assert.match(indicator, /Lifecycle:/)
  assert.match(indicator, /Parcel:/)
  assert.match(indicator, /COD:/)
  assert.match(indicator, /data-status-kind=/)
})

test('P6-T109 surfaces the indicators in the Orders workspace', () => {
  assert.match(selection, /OperationalStatusIndicators/)
  assert.match(selection, /Operational Status/)
})

test('P6-T109 reads the authoritative parcel and COD states exposed by the Orders API', () => {
  assert.match(worker, /parcels\(id,state,shipper_id,tracking_id\)/)
  assert.match(worker, /cod_obligations\(state\)/)
  assert.match(worker, /parcels\.state/)
  assert.match(worker, /cod_obligations\.state/)
})
