import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const source = fs.readFileSync(new URL('../../src/lib/scannerInput.ts', import.meta.url), 'utf8')
const functionMatch = source.match(/export function normalizeScannerInput\(raw: string, options: ScannerInputOptions = \{\}\): string \{([\s\S]*?)\n\}/)
assert.ok(functionMatch, 'normalizeScannerInput must be present')
const consumeMatch = source.match(/export function consumeScannerKey\(buffer: string, key: string, options: ScannerInputOptions = \{\}\): \{([\s\S]*?)\n\}/)
assert.ok(consumeMatch, 'consumeScannerKey must be present')

const normalizeScannerInput = new Function('raw', 'options', functionMatch[1])
const consumeScannerKey = new Function('buffer', 'key', 'options', consumeMatch[1])

function scanKeys(payload, terminator = 'Enter') {
  let buffer = ''
  let value = null
  for (const key of [...payload, terminator]) {
    const result = consumeScannerKey(buffer, key, {})
    buffer = result.buffer
    value = result.value
  }
  return { buffer, value }
}

test('keyboard-wedge scan round-trips a Code 128 parcel payload and Enter terminator', () => {
  const payload = 'PCL/2026-09-14-000123'
  const result = scanKeys(payload)
  assert.equal(result.value, payload)
  assert.equal(result.buffer, '')
})

test('CR and LF are accepted only as trailing scanner transport terminators', () => {
  assert.equal(normalizeScannerInput('PKG123456789\r\n'), 'PKG123456789')
  assert.throws(() => normalizeScannerInput('PKG123\n456'), /unsupported control characters/)
})

test('scanner input remains printable ASCII and rejects unsupported controls', () => {
  assert.equal(normalizeScannerInput('ABC 123'), 'ABC 123')
  assert.throws(() => normalizeScannerInput('ABC\t123'), /unsupported control characters/)
  assert.throws(() => normalizeScannerInput(''), /Scanner input is empty/)
})

test('non-character control keys do not alter the scanner buffer', () => {
  const first = consumeScannerKey('', 'Shift', {})
  assert.deepEqual(first, { buffer: '', value: null })
  const second = consumeScannerKey('PCL', 'F1', {})
  assert.deepEqual(second, { buffer: 'PCL', value: null })
})

test('maximum scanner payload length is enforced', () => {
  assert.throws(() => normalizeScannerInput('A'.repeat(129)), /maximum length/)
  assert.equal(normalizeScannerInput('A'.repeat(128)).length, 128)
})
