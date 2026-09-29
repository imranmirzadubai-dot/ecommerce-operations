import { CODE128_PATTERNS, type InvoiceSource } from './invoice'

const PAGE_WIDTH = 595
const PAGE_HEIGHT = 842
const LEFT = 42
const RIGHT = 553
const TOP = 795

function safePdfText(value: string): string {
  return Array.from(value, (character) => {
    const code = character.charCodeAt(0)
    return code >= 32 && code <= 126 ? character : '?'
  }).join('')
}

function escapePdfString(value: string): string {
  return safePdfText(value).replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)')
}

function pdfText(x: number, y: number, text: string, size = 10, bold = false): string {
  const font = bold ? '/F2' : '/F1'
  return `BT ${font} ${size} Tf ${x.toFixed(2)} ${y.toFixed(2)} Td (${escapePdfString(text)}) Tj ET`
}

function pdfLine(x1: number, y1: number, x2: number, y2: number, width = 1): string {
  return `${width.toFixed(2)} w ${x1.toFixed(2)} ${y1.toFixed(2)} m ${x2.toFixed(2)} ${y2.toFixed(2)} l S`
}

function pdfBarcode(value: string, x: number, y: number, targetWidth: number, height = 48): string {
  const codeValues = Array.from(value).map((character) => character.charCodeAt(0) - 32)
  if (codeValues.some((code) => code < 0 || code >= 103)) {
    return pdfText(x, y - 14, value, 8)
  }

  const checksum = (104 + codeValues.reduce((sum, code, index) => sum + code * (index + 1), 0)) % 103
  const symbols = [104, ...codeValues, checksum, 106]
  const moduleWidth = 2
  const naturalWidth = symbols.reduce((total, symbol) => {
    const pattern = CODE128_PATTERNS[symbol]
    return total + Array.from(pattern, Number).reduce((sum, width) => sum + width, 0) * moduleWidth
  }, 0)
  const scale = targetWidth / naturalWidth
  let cursor = x
  const commands: string[] = []
  for (const symbol of symbols) {
    const pattern = CODE128_PATTERNS[symbol]
    let isBar = true
    for (const widthValue of pattern) {
      const width = Number(widthValue) * moduleWidth * scale
      if (isBar) commands.push(`${cursor.toFixed(2)} ${y.toFixed(2)} ${width.toFixed(2)} ${height.toFixed(2)} re f`)
      cursor += width
      isBar = !isBar
    }
  }
  commands.push(pdfText(x + targetWidth / 2 - safePdfText(value).length * 2.3, y - 14, value, 8))
  return commands.join('\n')
}

function renderPage(source: InvoiceSource, pageNumber: number, pageCount: number): string {
  const commands: string[] = []
  commands.push('0 G')
  commands.push(pdfText(LEFT, TOP, 'INVOICE', 22, true))
  commands.push(pdfText(350, TOP + 2, `Invoice No. ${source.invoiceNumber}`, 9))
  commands.push(pdfText(350, TOP - 14, `Order ID ${source.orderNumber}`, 9, true))
  commands.push(pdfText(350, TOP - 30, `Date ${source.orderDate}`, 9))
  if (source.trackingId) commands.push(pdfText(350, TOP - 46, `Tracking ID ${source.trackingId}`, 9))
  commands.push(pdfLine(LEFT, TOP - 58, RIGHT, TOP - 58, 1.5))

  commands.push(pdfText(LEFT, TOP - 82, 'CUSTOMER', 9, true))
  commands.push(pdfText(LEFT, TOP - 100, source.customer.name, 12, true))
  let customerY = TOP - 116
  for (const value of [source.customer.phone, source.customer.address, source.customer.city]) {
    if (value) {
      commands.push(pdfText(LEFT, customerY, value, 9))
      customerY -= 14
    }
  }

  commands.push(pdfText(380, TOP - 82, 'PARCEL BARCODE', 9, true))
  commands.push(pdfBarcode(source.parcelNumber, 380, TOP - 150, 165, 42))

  let y = TOP - 205
  commands.push(pdfText(LEFT, y, 'ITEMS', 9, true))
  y -= 18
  commands.push(pdfText(LEFT, y, 'LINE', 8, true))
  commands.push(pdfText(90, y, 'DESCRIPTION', 8, true))
  commands.push(pdfText(500, y, 'QTY', 8, true))
  commands.push(pdfLine(LEFT, y - 6, RIGHT, y - 6, 0.8))
  y -= 24

  for (const item of source.items) {
    if (y < 125) break
    commands.push(pdfText(LEFT, y, String(item.lineNo), 9))
    commands.push(pdfText(90, y, item.description, 9))
    commands.push(pdfText(500, y, String(item.quantity), 9))
    commands.push(pdfLine(LEFT, y - 7, RIGHT, y - 7, 0.35))
    y -= 24
  }

  commands.push(pdfLine(310, y - 4, RIGHT, y - 4, 1.2))
  commands.push(pdfText(330, y - 24, 'Total Order Amount', 10, true))
  commands.push(pdfText(470, y - 24, `AED ${source.originalAmount.toFixed(2)}`, 10, true))
  commands.push(pdfLine(LEFT, 80, RIGHT, 80, 0.5))
  commands.push(pdfText(LEFT, 62, `Template ${source.templateVersion} · Generated ${source.generatedAt}`, 7))
  commands.push(pdfText(520, 62, `${pageNumber}/${pageCount}`, 7))

  return commands.join('\n')
}

function encodeAscii(value: string): Uint8Array {
  return new TextEncoder().encode(value)
}

export function renderInvoicePdf(sources: InvoiceSource[]): Uint8Array {
  if (sources.length === 0) throw new Error('At least one invoice is required')
  const objects: string[] = []
  objects.push('<< /Type /Catalog /Pages 2 0 R >>')
  const pageObjectIds: number[] = []
  const contentObjectIds: number[] = []
  for (let index = 0; index < sources.length; index += 1) {
    pageObjectIds.push(5 + index * 2)
    contentObjectIds.push(6 + index * 2)
  }
  objects.push(`<< /Type /Pages /Kids [ ${pageObjectIds.map((id) => `${id} 0 R`).join(' ')} ] /Count ${sources.length} >>`)
  objects.push('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
  objects.push('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>')

  for (let index = 0; index < sources.length; index += 1) {
    const pageId = pageObjectIds[index]
    const contentId = contentObjectIds[index]
    const stream = renderPage(sources[index], index + 1, sources.length)
    objects[pageId - 1] = `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${contentId} 0 R >>`
    objects[contentId - 1] = `<< /Length ${encodeAscii(stream).byteLength} >>\nstream\n${stream}\nendstream`
  }

  let pdf = '%PDF-1.4\n%1234\n'
  const offsets: number[] = [0]
  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(encodeAscii(pdf).byteLength)
    pdf += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`
  }
  const xrefOffset = encodeAscii(pdf).byteLength
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`
  for (let index = 1; index <= objects.length; index += 1) {
    pdf += `${String(offsets[index]).padStart(10, '0')} 00000 n \n`
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`
  return encodeAscii(pdf)
}
