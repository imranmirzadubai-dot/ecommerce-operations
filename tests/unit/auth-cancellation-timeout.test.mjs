import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const source = fs.readFileSync(path.join(root, 'src/lib/commands.ts'), 'utf8')

test('AUTH-005 gives command requests an explicit caller cancellation boundary', () => {
  assert.match(source, /export const COMMAND_REQUEST_TIMEOUT_MS = 8_000/)
  assert.match(source, /signal\?: AbortSignal/)
  assert.match(source, /signal\?\.addEventListener\('abort', abort, \{ once: true \}\)/)
  assert.match(source, /signal: controller\.signal/)
  assert.match(source, /signal\?\.removeEventListener\('abort', abort\)/)
})

test('AUTH-005 converts internal timeout aborts into a deterministic timeout error', () => {
  assert.match(source, /setTimeout\(\(\) => controller\.abort\(new DOMException\('Request timed out', 'TimeoutError'\)/)
  assert.match(source, /signal\?\.aborted\) throw error/)
  assert.match(source, /throw new Error\('Request timed out', \{ cause: error \}\)/)
})

test('AUTH-005 propagates cancellation through all cancellable data operations', () => {
  for (const functionName of [
    'resolveCustomerByPhone',
    'createOrder',
    'updateOrder',
    'confirmOrder',
    'createCodObligation',
    'allocateCodObligationToParcel',
    'getOrderTimeline',
    'getCustomerHistory',
  ]) {
    assert.match(source, new RegExp(`export async function ${functionName}\\([\\s\\S]*?signal\\?: AbortSignal`))
  }
  assert.match(source, /type ListOrdersOptions = [^\n]*signal\?: AbortSignal/)
  assert.match(source, /options\.signal/)
})
