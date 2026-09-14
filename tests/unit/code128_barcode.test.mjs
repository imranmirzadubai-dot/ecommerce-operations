import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const invoiceSource = fs.readFileSync(new URL('../../src/lib/invoice.ts', import.meta.url), 'utf8')
const patternMatch = invoiceSource.match(/const CODE128_PATTERNS = \[([\s\S]*?)\n\] as const/)
assert.ok(patternMatch, 'invoice renderer must define the Code 128 symbol table')
const patterns = [...patternMatch[1].matchAll(/'([0-9]+)'/g)].map((match) => match[1])

const functionMatch = invoiceSource.match(/function renderCode128Barcode\(value: string\): string \{([\s\S]*?)\n\}\n\nfunction validateSource/)
assert.ok(functionMatch, 'invoice renderer must define renderCode128Barcode')
const rendererBody = functionMatch[1].replace(/:\s*string\[\]/g, '')
const renderCode128Barcode = new Function('CODE128_PATTERNS', `return function renderCode128Barcode(value) {${rendererBody}\n}`)(patterns)

function expectedChecksum(value) {
  const codeValues = Array.from(value).map((character) => character.charCodeAt(0) - 32)
  return (104 + codeValues.reduce((sum, code, index) => sum + code * (index + 1), 0)) % 103
}

test('Code 128 symbol table contains all 107 symbols', () => {
  assert.equal(patterns.length, 107)
  assert.equal(patterns[104], '211214', 'Code 128-B START is symbol 104')
  assert.equal(patterns[106], '2331112', 'Code 128 STOP is symbol 106')
})

test('Code 128-B checksum matches independent known vectors', () => {
  const expected = {
    'PCL-000001': 3,
    'PKG123456789': 73,
    'ABC 123': 18,
  }
  for (const [value, checksum] of Object.entries(expected)) {
    assert.equal(expectedChecksum(value), checksum)
    assert.equal(Array.from(value).every((character) => character.charCodeAt(0) >= 32 && character.charCodeAt(0) <= 127), true)
  }
})

test('barcode renderer emits valid Code 128 structure and preserves the encoded parcel value', () => {
  const value = 'PCL-000001'
  const html = renderCode128Barcode(value)
  const checksum = expectedChecksum(value)
  const symbols = [104, ...Array.from(value).map((character) => character.charCodeAt(0) - 32), checksum, 106]
  const expectedModuleWidth = 2
  const expectedWidth = symbols.reduce((total, symbol) => total + [...patterns[symbol]].reduce((sum, width) => sum + Number(width), 0) * expectedModuleWidth, 0)

  assert.match(html, /^<svg class="invoice-barcode-svg"/)
  assert.match(html, /role="img"/)
  assert.match(html, /aria-label="Parcel barcode PCL-000001"/)
  assert.match(html, /<g fill="#171717">/)
  assert.match(html, new RegExp(`viewBox="0 0 ${expectedWidth} 78"`))
  assert.match(html, /<text[^>]*>PCL-000001<\/text>/)

  const barCount = (html.match(/<rect /g) ?? []).length
  const expectedBarCount = symbols.reduce((count, symbol) => {
    const pattern = patterns[symbol]
    return count + [...pattern].filter((_, index) => index % 2 === 0).length
  }, 0)
  assert.equal(barCount, expectedBarCount)
})

test('barcode renderer escapes the human-readable parcel value', () => {
  const html = renderCode128Barcode('PCL<&')
  assert.match(html, /aria-label="Parcel barcode PCL&lt;&amp;"/)
  assert.match(html, /<text[^>]*>PCL&lt;&amp;<\/text>/)
})
