import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const commands = fs.readFileSync(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')
const workspace = fs.readFileSync(new URL('../../src/components/OrdersWorkspace.tsx', import.meta.url), 'utf8')
const worker = fs.readFileSync(new URL('../../worker/index.ts', import.meta.url), 'utf8')

test('T107 exposes the locked quick date views and custom range controls', () => {
  for (const label of ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Custom']) assert.match(workspace, new RegExp(label.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')))
  assert.match(workspace, /type="date"/)
  assert.match(workspace, /applyCustomDateRange/)
})

test('T107 sends date range state through the existing paginated order request', () => {
  assert.match(commands, /dateFrom\?: string; dateTo\?: string/)
  assert.match(commands, /query\.set\('date_from', dateFrom\)/)
  assert.match(commands, /query\.set\('date_to', dateTo\)/)
  assert.match(workspace, /dateFrom: targetDateFrom, dateTo: targetDateTo/)
  assert.match(workspace, /refresh\(page - 1\)/)
  assert.match(workspace, /refresh\(page \+ 1\)/)
})

test('T107 filters on authoritative order_date and rejects invalid ranges server-side', () => {
  assert.match(worker, /const dateFrom = url\.searchParams\.get\("date_from"\)/)
  assert.match(worker, /const dateTo = url\.searchParams\.get\("date_to"\)/)
  assert.match(worker, /invalid_date_range/)
  assert.match(worker, /query\.set\("order_date", `gte\.\$\{dateFrom\}`\)/)
  assert.match(worker, /query\.set\("order_date", `lte\.\$\{dateTo\}`\)/)
  assert.match(worker, /order_date\.desc,created_at\.desc,id\.desc/)
  assert.match(worker, /order_date,created_at,updated_at/)
})
