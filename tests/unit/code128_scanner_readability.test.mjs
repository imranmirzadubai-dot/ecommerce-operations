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
const escapeHtml = (value) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;')
const renderCode128Barcode = new Function('CODE128_PATTERNS', 'escapeHtml', `return function renderCode128Barcode(value) {${rendererBody}\n}`)(patterns, escapeHtml)

function checksumFor(value) {
  const values = Array.from(value).map((character) => character.charCodeAt(0) - 32)
  return (104 + values.reduce((sum, code, index) => sum + code * (index + 1), 0)) % 103
}

function parseSvgBars(svg) {
  const rects = [...svg.matchAll(/<rect x="(\d+)" y="0" width="(\d+)" height="60"\/>/g)]
  assert.ok(rects.length > 0, 'barcode must contain scanner-visible bar rectangles')
  return rects.map((match) => ({ x: Number(match[1]), width: Number(match[2]) }))
}

function decodeScannerRun(symbolWidths) {
  const modules = symbolWidths.map((width) => width / 2)
  const symbols = []
  let cursor = 0
  while (cursor < modules.length) {
    const pattern = modules.slice(cursor, cursor + 6).join('')
    const symbol = patterns.findIndex((candidate) => candidate === pattern)
    assert.notEqual(symbol, -1, `scanner run ${pattern} must map to a Code 128 symbol`)
    symbols.push(symbol)
    cursor += 6
    if (symbol === 106) break
  }
  return symbols
}

function decodeCode128B(svg) {
  const bars = parseSvgBars(svg)
  const firstBar = bars[0]
  const runs = []
  let x = 0
  for (const bar of bars) {
    if (bar.x > x) runs.push(bar.x - x)
    runs.push(bar.width)
    x = bar.x + bar.width
  }

  // Reconstruct the complete alternating black/white module stream from the SVG.
  const expectedWidth = Number(svg.match(/viewBox="0 0 (\d+) 78"/)?.[1])
  assert.equal(x, expectedWidth)
  assert.equal(firstBar.x, 0, 'barcode must begin with a black bar')

  const moduleRuns = []
  let position = 0
  for (const bar of bars) {
    if (bar.x > position) moduleRuns.push(bar.x - position)
    moduleRuns.push(bar.width)
    position = bar.x + bar.width
  }
  if (position < expectedWidth) moduleRuns.push(expectedWidth - position)

  const symbols = []
  let runIndex = 0
  while (runIndex < moduleRuns.length) {
    const pattern = moduleRuns.slice(runIndex, runIndex + 6).map((width) => String(width / 2)).join('')
    const symbol = patterns.findIndex((candidate) => candidate === pattern)
    assert.notEqual(symbol, -1, `scanner run ${pattern} must map to a Code 128 symbol`)
    symbols.push(symbol)
    runIndex += 6
    if (symbol === 106) break
  }

  assert.equal(symbols[0], 104, 'scanner decode must see Code 128-B START')
  assert.equal(symbols.at(-1), 106, 'scanner decode must see Code 128 STOP')

  const data = symbols.slice(1, -2)
  const checksum = symbols.at(-2)
  const value = String.fromCharCode(...data.map((code) => code + 32))
  assert.equal(checksum, checksumFor(value), 'scanner decode checksum must validate')
  return value
}

test('scanner-style decode round-trips representative parcel values', () => {
  for (const value of ['PCL-000001', 'PKG123456789', 'ABC 123', 'PCL/2026-09-14-000123']) {
    const svg = renderCode128Barcode(value)
    assert.equal(decodeCode128B(svg), value)
  }
})

test('scanner-visible bars have deterministic positions and module-aligned widths', () => {
  const svg = renderCode128Barcode('PCL-000001')
  const bars = parseSvgBars(svg)
  for (const bar of bars) {
    assert.equal(bar.x % 2, 0)
    assert.equal(bar.width % 2, 0)
    assert.ok(bar.width >= 2)
  }
  for (let index = 1; index < bars.length; index += 1) {
    assert.ok(bars[index].x > bars[index - 1].x, 'bars must advance monotonically')
  }
})

test('scanner-readable barcode preserves the human-readable parcel value', () => {
  const value = 'PKG123456789'
  const svg = renderCode128Barcode(value)
  assert.match(svg, new RegExp(`<text[^>]*>${value}</text>`))
  assert.match(svg, new RegExp(`aria-label="Parcel barcode ${value}"`))
})
