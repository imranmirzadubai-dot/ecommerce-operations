import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const component = await readFile(new URL('../../src/components/CustomerHistoryWorkspace.tsx', import.meta.url), 'utf8')

test('customer history API requires authentication and validates customer id', () => {
  assert.match(worker, /historyMatch/)
  assert.match(worker, /\/api\/customers\/\/api\/customers\/|history\$\/\)/)
  assert.match(worker, /if \(!accessToken\) return json\(\{ error: "authentication_required" \}, 401/)
  assert.match(worker, /invalid_customer_id/)
})

test('customer history API queries only the requested customer orders', () => {
  assert.match(worker, /customer_id: `eq\.\$\{customerId\}`/)
  assert.match(worker, /select: "id,order_number,order_date,lifecycle_state,original_amount"/)
  assert.match(worker, /limit: "100"/)
})

test('customer history client uses the authenticated worker API', () => {
  assert.match(commands, /\/api\/customers\/\$\{encodeURIComponent\(customerId\)\}\/history/)
  assert.match(commands, /Authorization: `Bearer \$\{accessToken\}`/)
  assert.match(component, /resolveCustomerByPhone\(accessToken, phone\.trim\(\)\)/)
  assert.match(component, /getCustomerHistory\(accessToken, match\.customer_id\)/)
})
