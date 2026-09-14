import { useEffect, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { renderInvoiceHtml, type InvoiceSource } from '../lib/invoice'

type Props = { accessToken: string }
type InvoiceRecord = {
  id: string
  invoice_number: string
  template_version: string
  generated_at: string
  source_snapshot: InvoiceSource
  orders: { order_number: string } | null
}
type ErrorPayload = { message?: string; error?: string; details?: string }
type PrintResult = { print_event_id: string; print_count: number }

async function listInvoices(accessToken: string): Promise<InvoiceRecord[]> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const select = 'id,invoice_number,template_version,generated_at,source_snapshot,orders!inner(order_number)'
  const response = await fetch(`${config.url}/rest/v1/invoice_records?select=${encodeURIComponent(select)}&order=generated_at.desc`, {
    headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = await response.json().catch(() => null) as InvoiceRecord[] | ErrorPayload | null
  if (!response.ok) {
    const error = payload as ErrorPayload | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Invoice request failed (${response.status})`)
  }
  return Array.isArray(payload) ? payload : []
}

async function recordPrint(accessToken: string, invoiceRecordId: string, mode: 'individual' | 'batch'): Promise<PrintResult> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase authentication is not configured for this environment')
  const response = await fetch(`${config.url}/rest/v1/rpc/record_invoice_print`, {
    method: 'POST',
    headers: {
      apikey: config.publishableKey,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({ p_invoice_record_id: invoiceRecordId, p_print_mode: mode, p_metadata: { client: 'operations-web', action: `${mode}_print` } }),
  })
  const payload = await response.json().catch(() => null) as PrintResult[] | ErrorPayload | null
  if (!response.ok) {
    const error = payload as ErrorPayload | null
    throw new Error(error?.message ?? error?.details ?? error?.error ?? `Print event failed (${response.status})`)
  }
  const result = Array.isArray(payload) ? payload[0] : null
  if (!result) throw new Error('Print event completed without returning its event record')
  return result
}

function toInvoiceSource(record: InvoiceRecord): InvoiceSource {
  if (!record.source_snapshot) throw new Error('Invoice record is missing its historical source snapshot')
  if (record.source_snapshot.templateVersion !== record.template_version) {
    throw new Error('Invoice historical snapshot template version does not match its invoice record')
  }
  return {
    ...record.source_snapshot,
    originalAmount: Number(record.source_snapshot.originalAmount),
    items: record.source_snapshot.items.map((item) => ({
      lineNo: item.lineNo,
      description: item.description,
      quantity: item.quantity,
    })),
  }
}

function openPrintWindow(html?: string): Window | null {
  const printWindow = window.open('', '_blank', 'noopener,noreferrer')
  if (!printWindow) return null
  if (html !== undefined) {
    printWindow.document.open()
    printWindow.document.write(html)
    printWindow.document.close()
    printWindow.addEventListener('load', () => {
      printWindow.focus()
      printWindow.print()
    }, { once: true })
  }
  return printWindow
}

export function InvoicePrintWorkspace({ accessToken }: Props) {
  const [records, setRecords] = useState<InvoiceRecord[]>([])
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [printingId, setPrintingId] = useState<string | null>(null)
  const [batchPrinting, setBatchPrinting] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function refresh() {
    setLoading(true)
    setError('')
    try {
      setRecords(await listInvoices(accessToken))
      setSelectedIds([])
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to load invoices')
    } finally {
      setLoading(false)
    }
  }

  async function printInvoice(record: InvoiceRecord) {
    if (printingId || batchPrinting) return
    setPrintingId(record.id)
    setMessage('')
    setError('')
    try {
      const source = toInvoiceSource(record)
      const printWindow = openPrintWindow(renderInvoiceHtml(source))
      if (!printWindow) throw new Error('The browser blocked the print window. Allow pop-ups for this application and try again.')
      const event = await recordPrint(accessToken, record.id, 'individual')
      setMessage(`${record.invoice_number} sent to print. Event ${event.print_event_id.slice(0, 8)} recorded; print count is now ${event.print_count}.`)
    } catch (printError) {
      setError(printError instanceof Error ? printError.message : 'Unable to print invoice')
    } finally {
      setPrintingId(null)
    }
  }

  async function printBatch() {
    if (printingId || batchPrinting || selectedIds.length === 0) return
    setBatchPrinting(true)
    setMessage('')
    setError('')
    try {
      const selected = selectedIds.map((id) => records.find((record) => record.id === id)).filter((record): record is InvoiceRecord => record !== undefined)
      if (selected.length !== selectedIds.length) throw new Error('One or more selected invoices are no longer available. Refresh and try again.')
      const sources = selected.map(toInvoiceSource)
      const html = sources.map((source) => renderInvoiceHtml(source)).join('<div style="page-break-after: always"></div>')
      const printWindow = openPrintWindow()
      if (!printWindow) throw new Error('The browser blocked the print window. Allow pop-ups for this application and try again.')
      const events = []
      for (const record of selected) events.push(await recordPrint(accessToken, record.id, 'batch'))
      printWindow.document.open()
      printWindow.document.write(html)
      printWindow.document.close()
      printWindow.addEventListener('load', () => {
        printWindow.focus()
        printWindow.print()
      }, { once: true })
      setMessage(`${selected.length} invoices sent to batch print. ${events.length} batch print events recorded.`)
      setSelectedIds([])
    } catch (printError) {
      setError(printError instanceof Error ? printError.message : 'Unable to batch print invoices')
    } finally {
      setBatchPrinting(false)
    }
  }

  function toggleSelected(id: string) {
    setSelectedIds((current) => current.includes(id) ? current.filter((selectedId) => selectedId !== id) : [...current, id])
  }

  function toggleAll() {
    setSelectedIds((current) => current.length === records.length ? [] : records.map((record) => record.id))
  }

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try {
        const rows = await listInvoices(accessToken)
        if (!cancelled) setRecords(rows)
      } catch (requestError) {
        if (!cancelled) setError(requestError instanceof Error ? requestError.message : 'Unable to load invoices')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void load()
    return () => { cancelled = true }
  }, [accessToken])

  const busy = loading || printingId !== null || batchPrinting

  return <section className="card invoice-print-workspace" aria-labelledby="invoice-print-title">
    <div className="section-heading">
      <div>
        <span className="eyebrow">Invoices</span>
        <h2 id="invoice-print-title">Individual &amp; Batch Printing</h2>
        <p>Print historical invoices from their immutable generation snapshots and stored template versions. Every print action is recorded transactionally.</p>
      </div>
      <div>
        <button className="secondary-button" type="button" onClick={() => void refresh()} disabled={busy}>{loading ? 'Loading…' : 'Refresh'}</button>
        {records.length > 0 && <button className="login-button" type="button" onClick={() => void printBatch()} disabled={busy || selectedIds.length === 0}>{batchPrinting ? 'Preparing batch…' : `Print selected (${selectedIds.length})`}</button>}
      </div>
    </div>
    {error && <p className="form-error" role="alert">{error}</p>}
    {message && <p className="form-success" role="status">{message}</p>}
    {!error && loading && <p className="form-note">Loading invoice records…</p>}
    {!error && !loading && records.length === 0 && <p className="empty-state">No generated invoice records are available for printing.</p>}
    {!error && !loading && records.length > 0 && <div className="orders-table-wrap">
      <table className="orders-table">
        <thead><tr>
          <th><input aria-label="Select all invoices" type="checkbox" checked={selectedIds.length === records.length} onChange={toggleAll} disabled={busy} /></th>
          <th>Invoice</th><th>Order</th><th>Template</th><th>Generated</th><th>Action</th>
        </tr></thead>
        <tbody>{records.map((record) => <tr key={record.id}>
          <td><input aria-label={`Select ${record.invoice_number}`} type="checkbox" checked={selectedIds.includes(record.id)} onChange={() => toggleSelected(record.id)} disabled={busy} /></td>
          <td>{record.invoice_number}</td>
          <td>{record.source_snapshot.orderNumber ?? record.orders?.order_number ?? '—'}</td>
          <td>{record.template_version}</td>
          <td>{new Date(record.generated_at).toLocaleString()}</td>
          <td><button className="login-button" type="button" onClick={() => void printInvoice(record)} disabled={busy}>{printingId === record.id ? 'Preparing…' : 'Print invoice'}</button></td>
        </tr>)}</tbody>
      </table>
    </div>}
  </section>
}
