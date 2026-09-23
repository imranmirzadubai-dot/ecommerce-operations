import test from 'node:test'
import assert from 'node:assert/strict'
import { access, readFile } from 'node:fs/promises'

const root = new URL('../../src/components/', import.meta.url)
const selection = await readFile(new URL('OrderBatchSelection.tsx', root), 'utf8')
const workspace = await readFile(new URL('OrdersWorkspace.tsx', root), 'utf8')

async function exists(url) {
  try {
    await access(url)
    return true
  } catch {
    return false
  }
}

test('ARCH-003 has no duplicate OrdersWorkspace module stem', async () => {
  assert.equal(await exists(new URL('OrdersWorkspace.ts', root)), false)
  assert.match(workspace, /export function OrdersWorkspace\(/)
})

test('ARCH-003 removes the OrdersWorkspace to OrderBatchSelection cycle', () => {
  assert.match(selection, /from ['"]\.\/OrdersWorkspace['"]/) 
  assert.doesNotMatch(workspace, /from ['"]\.\/OrderBatchSelection['"]/) 
})
