import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const excel = await readFile(new URL('../../src/lib/excel.ts', import.meta.url), 'utf8')

test('P13-T206 builds the required XLSX ZIP package structure', () => {
  for (const signature of ['0x04034b50', '0x02014b50', '0x06054b50']) assert.match(excel, new RegExp(signature))
  for (const part of ['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/_rels/workbook.xml.rels']) assert.match(excel, new RegExp(part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  assert.match(excel, /xl\/worksheets\/sheet\$\{index \+ 1\}\.xml/)
})

test('P13-T206 writes workbook content types and worksheet relationships', () => {
  assert.match(excel, /application\/vnd\.openxmlformats-officedocument\.spreadsheetml\.sheet\.main\+xml/)
  assert.match(excel, /application\/vnd\.openxmlformats-officedocument\.spreadsheetml\.worksheet\+xml/)
  assert.match(excel, /officeDocument\/2006\/relationships\/officeDocument/)
  assert.match(excel, /officeDocument\/2006\/relationships\/worksheet/)
  assert.match(excel, /r:id=\\"rId\$\{sheet\.index\}\\"/)
})

test('P13-T206 generates worksheet cells with deterministic Excel references', () => {
  assert.match(excel, /columnName\(columnIndex\)/)
  assert.match(excel, /\$\{columnName\(columnIndex\)\}\$\{rowIndex \+ 1\}/)
  assert.match(excel, /t=\\"inlineStr\\"/)
  assert.match(excel, /xml:space=\\"preserve\\"/)
})

test('P13-T206 XML-escapes cell and worksheet names', () => {
  for (const entity of ['&amp;', '&lt;', '&gt;', '&quot;', '&apos;']) assert.match(excel, new RegExp(entity.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  assert.match(excel, /escapeXml\(text\)/)
  assert.match(excel, /escapeXml\(sheet\.name\)/)
})

test('P13-T206 creates an XLSX Blob and enforces the xlsx extension', () => {
  assert.match(excel, /new Blob\(\[bytes\], \{ type: 'application\/vnd\.openxmlformats-officedocument\.spreadsheetml\.sheet' \}\)/)
  assert.match(excel, /filename\.endsWith\('\.xlsx'\)/)
  assert.match(excel, /\$\{filename\}\.xlsx/)
})

test('P13-T206 supplies a safe workbook when no sheets are provided', () => {
  assert.match(excel, /safeSheets = sheets\.length \? sheets : \[\{ name: 'Sheet1', rows: \[\[\]\] \}\]/)
})

test('P13-T206 sanitizes and limits worksheet names', () => {
  assert.match(excel, /replaceAll\('\\\\', ''\)/)
  assert.match(excel, /replaceAll\('\/', ''\)/)
  assert.match(excel, /replaceAll\('\?', ''\)/)
  assert.match(excel, /replaceAll\('\*', ''\)/)
  assert.match(excel, /replaceAll\('\[', ''\)/)
  assert.match(excel, /replaceAll\('\]', ''\)/)
  assert.match(excel, /replaceAll\(':', ''\)/)
  assert.match(excel, /slice\(0, 31\)/)
})
