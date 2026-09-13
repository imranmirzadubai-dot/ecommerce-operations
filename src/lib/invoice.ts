export type InvoiceCustomer = {
  name: string
  phone: string | null
  address: string | null
  city: string | null
}

export type InvoiceItem = {
  lineNo: number
  description: string
  quantity: number
}

export type InvoiceSource = {
  invoiceNumber: string
  orderNumber: string
  parcelNumber: string
  templateVersion: string
  generatedAt: string
  orderDate: string
  currencyCode: 'AED'
  originalAmount: number
  customer: InvoiceCustomer
  items: InvoiceItem[]
  trackingId?: string | null
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function requiredText(value: string, field: string): string {
  const trimmed = value.trim()
  if (!trimmed) throw new Error(`${field} is required`)
  return trimmed
}

const CODE128_PATTERNS = [
  '212222','222122','222221','121223','121322','131222','122213','122312','132212','221213','221312','231212','112232','122132','122231','113222','123122','123221','223211','221132','221231','213212','223112','312131','311222','321122','321221','312212','322112','322211','212123','212321','232121','111323','131123','131321','112313','132113','132311','211313','231113','231311','112133','112331','132131','113123','113321','133121','313121','211331','231131','213113','213311','213131','311123','311321','331121','312113','312311','332111','314111','221411','431111','111224','111422','121124','121421','141122','141221','112214','112412','122114','122411','142112','142211','241211','221114','413111','241112','134111','111242','121142','121241','114212','124112','124211','411212','421112','421211','212141','214121','412121','111143','111341','131141','114113','114311','411113','411311','113141','114131','311141','411131','211412','211214','211232','2331112',
] as const

function renderCode128Barcode(value: string): string {
  const codeValues = Array.from(value).map((character) => character.charCodeAt(0) - 32)
  const checksum = (104 + codeValues.reduce((sum, code, index) => sum + code * (index + 1), 0)) % 103
  const symbols = [104, ...codeValues, checksum, 106]
  const moduleWidth = 2
  let x = 0
  const bars: string[] = []

  symbols.forEach((symbol) => {
    const pattern = CODE128_PATTERNS[symbol]
    let isBar = true
    for (const width of pattern) {
      const segmentWidth = Number(width) * moduleWidth
      if (isBar) bars.push(`<rect x="${x}" y="0" width="${segmentWidth}" height="60"/>`)
      x += segmentWidth
      isBar = !isBar
    }
  })

  return `<svg class="invoice-barcode-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${x} 78" role="img" aria-label="Parcel barcode ${escapeHtml(value)}" shape-rendering="crispEdges"><g fill="#171717">${bars.join('')}</g><text x="${x / 2}" y="73" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-size="11">${escapeHtml(value)}</text></svg>`
}

function validateSource(source: InvoiceSource): void {
  requiredText(source.invoiceNumber, 'Invoice number')
  requiredText(source.orderNumber, 'Order ID')
  const parcelNumber = requiredText(source.parcelNumber, 'Parcel number')
  if (!/^[\x20-\x7E]+$/.test(parcelNumber)) throw new Error('Parcel number must contain printable ASCII characters')
  requiredText(source.templateVersion, 'Template version')
  requiredText(source.generatedAt, 'Generated timestamp')
  requiredText(source.orderDate, 'Order date')
  if (source.currencyCode !== 'AED') throw new Error('Invoice currency must be AED')
  if (!Number.isFinite(source.originalAmount) || source.originalAmount < 0) throw new Error('Invoice amount must be zero or greater')
  requiredText(source.customer.name, 'Customer name')
  if (!Array.isArray(source.items) || source.items.length === 0) throw new Error('Invoice must contain at least one order item')
  source.items.forEach((item, index) => {
    if (!Number.isInteger(item.lineNo) || item.lineNo < 1) throw new Error(`Invalid invoice line ${index + 1}`)
    requiredText(item.description, `Invoice item ${index + 1} description`)
    if (!Number.isInteger(item.quantity) || item.quantity < 1) throw new Error(`Invalid invoice item ${index + 1} quantity`)
  })
}

function formatAmount(amount: number): string {
  return `AED ${amount.toFixed(2)}`
}

function renderCustomer(source: InvoiceSource): string {
  const lines = [
    `<div class="invoice-customer-name">${escapeHtml(source.customer.name)}</div>`,
    source.customer.phone ? `<div>${escapeHtml(source.customer.phone)}</div>` : '',
    source.customer.address ? `<div>${escapeHtml(source.customer.address)}</div>` : '',
    source.customer.city ? `<div>${escapeHtml(source.customer.city)}</div>` : '',
  ]
  return lines.filter(Boolean).join('\n')
}

function renderItems(source: InvoiceSource): string {
  return source.items.map((item) => `
    <tr>
      <td class="invoice-line-no">${item.lineNo}</td>
      <td>${escapeHtml(item.description)}</td>
      <td class="invoice-quantity">${item.quantity}</td>
    </tr>`).join('')
}

/**
 * Deterministic printable HTML renderer.
 *
 * The input is a snapshot assembled from authoritative database values. The
 * renderer does not calculate or invent commercial fields: the MVP has one
 * order-level original amount and integer order-item quantities only.
 */
export function renderInvoiceHtml(source: InvoiceSource): string {
  validateSource(source)
  const tracking = source.trackingId ? `<div><span class="invoice-label">Tracking ID</span>${escapeHtml(source.trackingId)}</div>` : ''
  const parcelBarcode = renderCode128Barcode(requiredText(source.parcelNumber, 'Parcel number'))

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Invoice ${escapeHtml(source.invoiceNumber)}</title>
<style>
@page { size: A4; margin: 12mm; }
body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #171717; background: #fff; }
.invoice { width: 100%; max-width: 190mm; margin: 0 auto; }
.invoice-header { display: flex; justify-content: space-between; gap: 24px; padding-bottom: 18px; border-bottom: 2px solid #171717; }
.invoice-title { margin: 0; font-size: 28px; letter-spacing: .08em; }
.invoice-meta { text-align: right; font-size: 12px; line-height: 1.6; }
.invoice-label { display: inline-block; min-width: 88px; font-weight: 700; }
.invoice-barcode { margin-top: 8px; text-align: right; }
.invoice-barcode .invoice-label { display: block; margin-bottom: 2px; }
.invoice-barcode-svg { display: block; width: 72mm; height: 24mm; margin-left: auto; }
.invoice-section { margin-top: 22px; }
.invoice-section h2 { margin: 0 0 8px; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; }
.invoice-customer { min-height: 74px; font-size: 13px; line-height: 1.6; }
.invoice-customer-name { font-weight: 700; font-size: 15px; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { padding: 9px 8px; border-bottom: 1px solid #d5d5d5; text-align: left; }
th { font-size: 11px; text-transform: uppercase; letter-spacing: .05em; }
.invoice-line-no, .invoice-quantity { width: 70px; text-align: center; }
.invoice-total { margin-top: 16px; margin-left: auto; width: 280px; border-top: 2px solid #171717; padding-top: 10px; display: flex; justify-content: space-between; font-weight: 700; }
.invoice-footer { margin-top: 28px; padding-top: 10px; border-top: 1px solid #d5d5d5; font-size: 10px; color: #555; }
@media print { .invoice { max-width: none; } }
</style>
</head>
<body>
<main class="invoice" data-template-version="${escapeHtml(source.templateVersion)}">
  <header class="invoice-header">
    <h1 class="invoice-title">INVOICE</h1>
    <div class="invoice-meta">
      <div><span class="invoice-label">Invoice No.</span>${escapeHtml(source.invoiceNumber)}</div>
      <div><span class="invoice-label">Order ID</span>${escapeHtml(source.orderNumber)}</div>
      <div><span class="invoice-label">Date</span>${escapeHtml(source.orderDate)}</div>
      ${tracking}
      <div class="invoice-barcode"><span class="invoice-label">Parcel Barcode</span>${parcelBarcode}</div>
    </div>
  </header>

  <section class="invoice-section">
    <h2>Customer</h2>
    <div class="invoice-customer">${renderCustomer(source)}</div>
  </section>

  <section class="invoice-section">
    <h2>Items</h2>
    <table>
      <thead><tr><th>Line</th><th>Description</th><th>Quantity</th></tr></thead>
      <tbody>${renderItems(source)}</tbody>
    </table>
    <div class="invoice-total"><span>Total Order Amount</span><span>${formatAmount(source.originalAmount)}</span></div>
  </section>

  <footer class="invoice-footer">Template ${escapeHtml(source.templateVersion)} · Generated ${escapeHtml(source.generatedAt)}</footer>
</main>
</body>
</html>`
}
