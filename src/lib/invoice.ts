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
    .replace(/\"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function requiredText(value: string, field: string): string {
  const trimmed = value.trim()
  if (!trimmed) throw new Error(`${field} is required`)
  return trimmed
}

function validateSource(source: InvoiceSource): void {
  requiredText(source.invoiceNumber, 'Invoice number')
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
 * Order ID and parcel barcode are intentionally added by later milestones.
 */
export function renderInvoiceHtml(source: InvoiceSource): string {
  validateSource(source)
  const tracking = source.trackingId ? `<div><span class="invoice-label">Tracking ID</span>${escapeHtml(source.trackingId)}</div>` : ''

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
      <div><span class="invoice-label">Date</span>${escapeHtml(source.orderDate)}</div>
      ${tracking}
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
