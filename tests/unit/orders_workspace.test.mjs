import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')

test('P6-T103 exposes the Orders workspace as the central authenticated workspace', () => {
  assert.match(app, /<OrdersWorkspace accessToken=\{auth\.accessToken!\} \/>/)
  assert.match(workspace, /<span className="eyebrow">Orders Workspace<\/span>/)
  assert.match(workspace, /<h2 id="orders-title">Recent Orders<\/h2>/)
})

test('Orders workspace displays the current order baseline and Draft actions', () => {
  assert.match(workspace, /<th>Order<\/th>/)
  assert.match(workspace, /<th>Customer<\/th>/)
  assert.match(workspace, /<th>State<\/th>/)
  assert.match(workspace, /<th>Amount<\/th>/)
  assert.match(workspace, /<th>Created<\/th>/)
  assert.match(workspace, /order\.lifecycle_state === 'Draft'/)
  assert.match(workspace, /Timeline/)
  assert.match(workspace, /Edit/)
  assert.match(workspace, /Confirm/)
})

test('Orders workspace reads through the authenticated server-side orders endpoint', () => {
  assert.match(commands, /export async function listOrders\(accessToken: string\)/)
  assert.match(commands, /fetch\('\/api\/orders'/)
  assert.match(workspace, /listOrders\(accessToken\)/)
})
