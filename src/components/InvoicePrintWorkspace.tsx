import { useEffect, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { renderInvoiceHtml, type InvoiceSource } from '../lib/invoice'

type Props = { accessToken: string }
type InvoiceRecord = { id: string; invoice_number: string; template_version: string; generated_at: string; orders: { order_number: string; order_date: string; currency_code: 'AED'; original_amount: number; customers: { name: string; phone: string | null; address: string | null; city: string | null } | null; order_items: { line_no: number; description: string; quantity: number }[]; parcels: { parcel_number: string; tracking_id: string | null }[] } | null }
type ErrorPayload = { message?: string; error?: string; details?: string }
type PrintResult = { print_event_id: string; print_count: number }

async function listInvoices(accessToken: string): Promise<InvoiceRecord[]> {
  const config = getAuthConfig(); if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const select = 'id,invoice_number,template_version,generated_at,orders!inner(order_number,order_date,currency_code,original_amount,customers(name,phone,address,city),order_items(line_no,description,quantity),parcels(parcel_number,tracking_id))'
  const response = await fetch(`${config.url}/rest/v1/invoice_records?select=${encodeURIComponent(select)}&order=generated_at.desc`, { headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } })
  const payload = await response.json().catch(() => null) as InvoiceRecord[] | ErrorPayload | null
  if (!response.ok) { const error = payload as ErrorPayload | null; throw new Error(error?.message ?? error?.details ?? error?.error ?? `Invoice request failed (${response.status})`) }
  return Array.isArray(payload) ? payload : []
}

async function recordPrint(accessToken: string, invoiceRecordId: string): Promise<PrintResult> {
  const config = getAuthConfig(); if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const response = await fetch(`${config.url}/rest/v1/rpc/record_invoice_print`, { method: 'POST', headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify({ p_invoice_record_id: invoiceRecordId, p_print_mode: 'individual', p_metadata: { client: 'operations-web', action: 'individual_print' } }) })
  const payload = await response.json().catch(() => null) as PrintResult[] | ErrorPayload | null
  if (!response.ok) { const error = payload as ErrorPayload | null; throw new Error(error?.message ?? error?.details ?? error?.error ?? `Print event failed (${response.status})`) }
  const result = Array.isArray(payload) ? payload[0] : null; if (!result) throw new Error('Print event completed without returning its event record'); return result
}

function toInvoiceSource(record: InvoiceRecord): InvoiceSource {
  const order = record.orders; if (!order) throw new Error('Invoice record is missing its order source'); if (!order.customers) throw new Error('Invoice order is missing its customer'); if (order.parcels.length !== 1) throw new Error('Individual invoice printing requires exactly one parcel for the order')
  const parcel = order.parcels[0]
  return { invoiceNumber: record.invoice_number, orderNumber: order.order_number, parcelNumber: parcel.parcel_number, templateVersion: record.template_version, generatedAt: record.generated_at, orderDate: order.order_date, currencyCode: order.currency_code, originalAmount: Number(order.original_amount), customer: order.customers, items: order.order_items.map((item) => ({ lineNo: item.line_no, description: item.description, quantity: item.quantity })), trackingId: parcel.tracking_id }
}

function openPrintWindow(html: string): Window | null { const printWindow = window.open('', '_blank', 'noopener,noreferrer'); if (!printWindow) return null; printWindow.document.open(); printWindow.document.write(html); printWindow.document.close(); printWindow.addEventListener('load', () => { printWindow.focus(); printWindow.print() }, { once: true }); return printWindow }

export function InvoicePrintWorkspace({ accessToken }: Props) {
  const [records, setRecords] = useState<InvoiceRecord[]>([]); const [loading, setLoading] = useState(true); const [printingId, setPrintingId] = useState<string | null>(null); const [message, setMessage] = useState(''); const [error, setError] = useState('')
  async function refresh() { setLoading(true); setError(''); try { setRecords(await listInvoices(accessToken)) } catch (requestError) { setError(requestError instanceof Error ? requestError.message : 'Unable to load invoices') } finally { setLoading(false) } }
  async function printInvoice(record: InvoiceRecord) { if (printingId) return; setPrintingId(record.id); setMessage(''); setError(''); try { const source = toInvoiceSource(record); const printWindow = openPrintWindow(renderInvoiceHtml(source)); if (!printWindow) throw new Error('The browser blocked the print window. Allow pop-ups for this application and try again.'); const event = await recordPrint(accessToken, record.id); setMessage(`${record.invoice_number} sent to print. Event ${event.print_event_id.slice(0, 8)} recorded; print count is now ${event.print_count}.`) } catch (printError) { setError(printError instanceof Error ? printError.message : 'Unable to print invoice') } finally { setPrintingId(null) } }
  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try { const rows = await listInvoices(accessToken); if (!cancelled) setRecords(rows) }
      catch (requestError) { if (!cancelled) setError(requestError instanceof Error ? requestError.message : 'Unable to load invoices') }
      finally { if (!cancelled) setLoading(false) }
    }
    void load(); return () => { cancelled = true }
  }, [accessToken])
  return <section className="card invoice-print-workspace" aria-labelledby="invoice-print-title"><div className="section-heading"><div><span className="eyebrow">Invoices</span><h2 id="invoice-print-title">Individual Printing</h2><p>Print one authoritative invoice using its stored template version and parcel barcode. The individual print event is recorded transactionally.</p></div><button className="secondary-button" type="button" onClick={() => void refresh()} disabled={loading || printingId !== null}>{loading ? 'Loading…' : 'Refresh'}</button></div>{error && <p className="form-error" role="alert">{error}</p>}{message && <p className="form-success" role="status">{message}</p>}{!error && loading && <p className="form-note">Loading invoice records…</p>}{!error && !loading && records.length === 0 && <p className="empty-state">No generated invoice records are available for individual printing.</p>}{!error && !loading && records.length > 0 && <div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Invoice</th><th>Order</th><th>Template</th><th>Generated</th><th>Action</th></tr></thead><tbody>{records.map((record) => <tr key={record.id}><td>{record.invoice_number}</td><td>{record.orders?.order_number ?? '—'}</td><td>{record.template_version}</td><td>{new Date(record.generated_at).toLocaleString()}</td><td><button className="login-button" type="button" onClick={() => void printInvoice(record)} disabled={printingId !== null}>{printingId === record.id ? 'Preparing…' : 'Print invoice'}</button></td></tr>)}</tbody></table></div>}</section>
}
