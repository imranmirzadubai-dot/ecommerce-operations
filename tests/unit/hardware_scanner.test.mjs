import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const source = fs.readFileSync(new URL('../../src/lib/hardwareScanner.ts', import.meta.url), 'utf8')

function loadParser() {
  const js = source
    .replace(/^export type[\s\S]*?^\/\*\*/m, '/**')
    .replace('export function parseScannerKeySequence', 'function parseScannerKeySequence')
    .replace(/: ScannerKey\[\]/g, '')
    .replace(/: ScannerInputConfig = \{\}/g, ' = {}')
    .replace(/: ScannerInputResult/g, '')
  const module = { exports: {} }
  new Function('module', 'exports', `${js}\nmodule.exports = { parseScannerKeySequence }`)(module, module.exports)
  return module.exports.parseScannerKeySequence
}

const parseScannerKeySequence = loadParser()
const events = (value, start = 0, gap = 10) => [...value].map((key, index) => ({ key, at: start + index * gap }))

test('accepts a rapid keyboard-wedge scan terminated by Enter', () => {
  assert.deepEqual(parseScannerKeySequence([...events('PCL-000001'), { key: 'Enter', at: 100 }]), { value: 'PCL-000001', accepted: true })
})

test('rejects an incomplete sequence without terminator', () => {
  assert.deepEqual(parseScannerKeySequence(events('PCL-000001')), { value: 'PCL-000001', accepted: false })
})

test('resets after a human-speed gap before accepting a scan', () => {
  const keys = [...events('PCL', 0, 10), ...events('-000001', 500, 10), { key: 'Enter', at: 570 }]
  assert.deepEqual(parseScannerKeySequence(keys), { value: '-000001', accepted: true })
})

test('rejects values shorter than the configured minimum', () => {
  assert.deepEqual(parseScannerKeySequence([...events('ABC'), { key: 'Enter', at: 40 }]), { value: 'ABC', accepted: false })
})

test('preserves punctuation and spaces emitted by the scanner', () => {
  assert.deepEqual(parseScannerKeySequence([...events('PKG 12-<&'), { key: 'Enter', at: 100 }]), { value: 'PKG 12-<&', accepted: true })
})
