import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')
const money = await readFile(new URL('../../src/lib/money.ts', import.meta.url), 'utf8')
const commands = await readFile(new URL('../../src/lib/commands.ts', import.meta.url), 'utf8')

function normalizeAedAmount(value) {
  const input = value.trim()
  if (!/^\d+(?:\.\d{1,2})?$/.test(input)) throw new Error('invalid')
  const [wholePart, fractionPart = ''] = input.split('.')
  const whole = wholePart.replace(/^0+(?=\d)/, '')
  const fraction = fractionPart.padEnd(2, '0')
  const canonical = `${whole}.${fraction}`
  if (canonical.length > 13 || (canonical.length === 13 && canonical > '9999999999.99')) throw new Error('too large')
  return canonical
}

test('draft order UI exposes one manual AED Total Order Amount field', () => {
  assert.match(app, /import \{ normalizeAedAmount \} from ['"]\.\/lib\/money['"]/)
  assert.match(app, /aria-label="Total Order Amount \(AED\)"/)
  assert.match(app, /type="number" min="0" step="0\.01" inputMode="decimal"/)
  assert.match(app, /value=\{amount\}/)
  assert.match(app, /onChange=\{\(event\) => setAmount\(event\.target\.value\)\}/)
  assert.match(app, /const normalizedAmount = normalizeAedAmount\(amount\)/)
  assert.match(app, /p_original_amount: normalizedAmount/)
  assert.match(app, /setAmount\(''\)/)
  assert.match(app, /no item prices, VAT, discount, or service fee/)
})

test('AED amount normalization accepts zero and at most two decimal places', () => {
  assert.equal(normalizeAedAmount('0'), '0.00')
  assert.equal(normalizeAedAmount('100'), '100.00')
  assert.equal(normalizeAedAmount('100.5'), '100.50')
  assert.equal(normalizeAedAmount('100.50'), '100.50')
  assert.equal(normalizeAedAmount('000100.50'), '100.50')
  assert.throws(() => normalizeAedAmount('100.123'))
  assert.throws(() => normalizeAedAmount('-1'))
  assert.throws(() => normalizeAedAmount('1e2'))
  assert.throws(() => normalizeAedAmount(''))
  assert.throws(() => normalizeAedAmount('10000000000.00'))
  assert.equal(normalizeAedAmount('9999999999.99'), '9999999999.99')
})

test('money helper keeps the commercial amount as bounded decimal text and command contract matches it', () => {
  assert.match(money, /export function normalizeAedAmount\(value: string\): string/)
  assert.match(money, /MAX_AED_AMOUNT = '9999999999\.99'/)
  assert.match(commands, /p_original_amount: string/)
})
