import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')
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

test('P6-T104 reads orders through the authenticated paginated server-side endpoint', () => {
  assert.match(commands, /export async function listOrders\(accessToken: string, options: ListOrdersOptions = \{\}\)/)
  assert.match(commands, /page_size/)
  assert.match(commands, /X-Has-More/)
  assert.match(workspace, /PAGE_SIZE = 25/)
  assert.match(workspace, /Previous/)
  assert.match(workspace, /Next/)
  assert.match(worker, /searchParams\.get\("page"\)/)
  assert.match(worker, /searchParams\.get\("page_size"\)/)
  assert.match(worker, /offset = \(rawPage - 1\) \* rawPageSize/)
  assert.match(worker, /limit: String\(limit\)/)
  assert.match(worker, /X-Has-More/)
})

test('P6-T105 provides server-side order search with safe input handling', () => {
  assert.match(commands, /search\?: string/)
  assert.match(commands, /query\.set\('search', search\)/)
  assert.match(workspace, /Search orders/)
  assert.match(workspace, /submitSearch/)
  assert.match(workspace, /Order ID, customer, phone, address or item/)
  assert.match(worker, /searchParams\.get\("search"\)/)
  assert.match(worker, /escapeSearchTerm/)
  assert.match(worker, /order_number\.ilike/)
  assert.match(worker, /customers\.name\.ilike/)
  assert.match(worker, /customers\.phone\.ilike/)
  assert.match(worker, /customers\.address\.ilike/)
  assert.match(worker, /order_items\.description\.ilike/)
  assert.match(worker, /invalid_search/)
})
