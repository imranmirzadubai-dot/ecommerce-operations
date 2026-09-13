import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const workspace = await readFile(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')

test('P6-T112 keeps historical orders in the normal Orders view unless a date filter is explicitly selected', () => {
  assert.match(workspace, /DATE_VIEWS = \['All dates', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Custom'\]/)
  assert.match(workspace, /setDateView\('All dates'\)/)
  assert.match(workspace, /dateFrom: '', dateTo: ''/)
  assert.match(worker, /const dateFrom = url\.searchParams\.get\("date_from"\)/)
  assert.match(worker, /const dateTo = url\.searchParams\.get\("date_to"\)/)
  assert.match(worker, /if \(dateFrom\) query\.set\("order_date", `gte\.\$\{dateFrom\}`\)/)
  assert.match(worker, /if \(dateTo\) query\.set\("order_date", `lte\.\$\{dateTo\}`\)/)
})

test('P6-T112 preserves server-side search for historical records in normal views', () => {
  assert.match(workspace, /Search runs server-side/)
  assert.match(commands, /query\.set\('search', search\)/)
  assert.match(worker, /const rawSearch = url\.searchParams\.get\("search"\) \?\? ""/)
  assert.match(worker, /order_number\.ilike/)
  assert.match(worker, /customers\.name\.ilike/)
  assert.match(worker, /order_items\.description\.ilike/)
  assert.match(worker, /order: "order_date\.desc,created_at\.desc,id\.desc"/)
})
