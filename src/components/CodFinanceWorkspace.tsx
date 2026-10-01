import { useState } from 'react'
import '../styles/cod-finance-responsive.css'
import { getAuthConfig } from '../lib/auth'

type Props = { accessToken: string; isAdmin: boolean }
type Order = { id: string; order_number: string; lifecycle_state: string; original_amount: number }
type Parcel = { id: string; parcel_number: string; barcode: string; state: string; tracking_id: string | null }
type Obligation = { id: string; order_id: string; expected_amount: number; state: string }
type Allocation = { id: string; cod_obligation_id: string; parcel_id: string; expected_amount: number; parcels: Parcel | null }
type Receipt = { id: string; cod_receipt_id?: string; cod_obligation_id: string; parcel_id: string; expected_amount_snapshot: number; received_amount: number; state: string; received_at: string }
type Reconciliation = {
  original_amount: number
  adjustment_total: number
  effective_amount: number
  cod_expected_amount: number
  allocated_expected_amount: number
  received_amount: number
  outstanding_amount: number
  receipt_variance: number
  unresolved_exception_count: number
  unreceived_allocation_count: number
  reconciliation_state: string
}

async function requestJson<T>(accessToken: string, path: string, init: RequestInit = {}): Promise<T> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this environment')
  const response = await fetch(path.startsWith('http') ? path : `${config.url}${path}`, {
    ...init,
    headers: {
      apikey: config.publishableKey,
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
      ...(init.headers ?? {}),
    },
  })
  const payload = await response.json().catch(() => null) as T | { message?: string; details?: string; error?: string } | null
  if (!response.ok) {
    const detail = payload as { message?: string; details?: string; error?: string } | null
    throw new Error(detail?.message ?? detail?.details ?? detail?.error ?? `Request failed (${response.status})`)
  }
  return payload as T
}

async function rpc<T>(accessToken: string, name: string, body: Record<string, unknown>): Promise<T> {
  return requestJson<T>(accessToken, `/rest/v1/rpc/${encodeURIComponent(name)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
}

function key() { return crypto.randomUUID() }

export function CodFinanceWorkspace({ accessToken, isAdmin }: Props) {
  const [orderNumber, setOrderNumber] = useState('')
  const [order, setOrder] = useState<Order | null>(null)
  const [parcels, setParcels] = useState<Parcel[]>([])
  const [obligation, setObligation] = useState<Obligation | null>(null)
  const [allocations, setAllocations] = useState<Allocation[]>([])
  const [receipts, setReceipts] = useState<Receipt[]>([])
  const [selectedParcelId, setSelectedParcelId] = useState('')
  const [allocationAmount, setAllocationAmount] = useState('')
  const [receiptParcelId, setReceiptParcelId] = useState('')
  const [receivedAmount, setReceivedAmount] = useState('')
  const [exceptionId, setExceptionId] = useState('')
  const [exceptionReason, setExceptionReason] = useState('')
  const [reconciliation, setReconciliation] = useState<Reconciliation | null>(null)
  const [loading, setLoading] = useState(false)
  const [working, setWorking] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function loadOrder(nextOrderNumber: string) {
    setLoading(true); setError(''); setMessage(''); setOrder(null); setObligation(null); setParcels([]); setAllocations([]); setReceipts([]); setReconciliation(null)
    try {
      const rows = await requestJson<Order[]>(accessToken, `/rest/v1/orders?order_number=eq.${encodeURIComponent(nextOrderNumber)}&select=id,order_number,lifecycle_state,original_amount&limit=1`)
      const found = rows[0]
      if (!found) throw new Error('Order not found')
      const [parcelRows, obligationRows] = await Promise.all([
        requestJson<Parcel[]>(accessToken, `/rest/v1/parcels?order_id=eq.${encodeURIComponent(found.id)}&select=id,parcel_number,barcode,state,tracking_id&order=parcel_number.asc`),
        requestJson<Obligation[]>(accessToken, `/rest/v1/cod_obligations?order_id=eq.${encodeURIComponent(found.id)}&select=id,order_id,expected_amount,state&limit=1`),
      ])
      setOrder(found)
      setParcels(parcelRows)
      const foundObligation = obligationRows[0] ?? null
      setObligation(foundObligation)
      if (foundObligation) await refreshFinancials(found.id, foundObligation.id)
      setMessage(`Order ${found.order_number} loaded.`)
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Unable to load order')
    } finally { setLoading(false) }
  }

  async function refreshFinancials(orderId: string, obligationId: string) {
    const [allocationRows, receiptRows] = await Promise.all([
      requestJson<Allocation[]>(accessToken, `/rest/v1/cod_obligation_allocations?cod_obligation_id=eq.${encodeURIComponent(obligationId)}&select=id,cod_obligation_id,parcel_id,expected_amount,parcels(id,parcel_number,barcode,state,tracking_id)&order=id.asc`),
      requestJson<Receipt[]>(accessToken, `/rest/v1/cod_receipts?cod_obligation_id=eq.${encodeURIComponent(obligationId)}&select=id,cod_obligation_id,parcel_id,expected_amount_snapshot,received_amount,state,received_at&order=received_at.desc`),
    ])
    setAllocations(allocationRows)
    setReceipts(receiptRows)
    if (isAdmin) {
      try {
        const rows = await rpc<Reconciliation[]>(accessToken, 'get_cod_financial_reconciliation', { p_order_id: orderId })
        setReconciliation(rows[0] ?? null)
      } catch {
        setReconciliation(null)
      }
    }
  }

  async function createObligation() {
    if (!order) return
    setWorking(true); setError(''); setMessage('')
    try {
      const rows = await rpc<Obligation[]>(accessToken, 'create_cod_obligation', { p_order_id: order.id, p_idempotency_key: key() })
      const created = rows[0]
      if (!created) throw new Error('COD obligation was not returned')
      setObligation(created)
      await refreshFinancials(order.id, created.id)
      setMessage(`COD obligation ready: AED ${Number(created.expected_amount).toFixed(2)} (${created.state}).`)
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to create COD obligation') }
    finally { setWorking(false) }
  }

  async function allocate() {
    if (!order || !obligation || !selectedParcelId) return
    const amount = Number(allocationAmount)
    if (!Number.isFinite(amount) || amount < 0) { setError('Enter a valid non-negative allocation amount'); return }
    setWorking(true); setError(''); setMessage('')
    try {
      const rows = await rpc<unknown[]>(accessToken, 'allocate_cod_obligation_to_parcel', {
        p_cod_obligation_id: obligation.id,
        p_parcel_id: selectedParcelId,
        p_expected_amount: amount.toFixed(2),
        p_idempotency_key: key(),
      })
      if (!rows[0]) throw new Error('COD allocation was not returned')
      await refreshFinancials(order.id, obligation.id)
      setMessage('COD obligation allocated to parcel.')
      setAllocationAmount('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to allocate COD') }
    finally { setWorking(false) }
  }

  async function recordReceipt() {
    if (!order || !obligation || !receiptParcelId) return
    const amount = Number(receivedAmount)
    if (!Number.isFinite(amount) || amount < 0) { setError('Enter a valid non-negative received amount'); return }
    setWorking(true); setError(''); setMessage('')
    try {
      const rows = await rpc<Receipt[]>(accessToken, 'record_cod_receipt', {
        p_cod_obligation_id: obligation.id,
        p_parcel_id: receiptParcelId,
        p_received_amount: amount.toFixed(2),
        p_idempotency_key: key(),
      })
      const receipt = rows[0]
      if (!receipt) throw new Error('COD receipt was not returned')
      await refreshFinancials(order.id, obligation.id)
      setMessage(`COD receipt recorded as ${receipt.state}. Expected AED ${Number(receipt.expected_amount_snapshot).toFixed(2)}; received AED ${Number(receipt.received_amount).toFixed(2)}.`)
      setReceivedAmount('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to record COD receipt') }
    finally { setWorking(false) }
  }

  async function resolveException() {
    if (!order || !exceptionId || !isAdmin) return
    setWorking(true); setError(''); setMessage('')
    try {
      const rows = await rpc<unknown[]>(accessToken, 'resolve_cod_exception', {
        p_cod_receipt_id: exceptionId,
        p_reason: exceptionReason,
        p_idempotency_key: key(),
      })
      if (!rows[0]) throw new Error('Exception resolution was not returned')
      await refreshFinancials(order.id, obligation!.id)
      setMessage('COD exception resolved through the append-only financial adjustment.')
      setExceptionId(''); setExceptionReason('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Unable to resolve COD exception') }
    finally { setWorking(false) }
  }

  const allocatedParcelIds = new Set(allocations.map((item) => item.parcel_id))
  const unallocatedParcels = parcels.filter((item) => !allocatedParcelIds.has(item.id) && item.state !== 'Cancelled')
  const receiptableAllocations = allocations.filter((item) => !receipts.some((receipt) => receipt.parcel_id === item.parcel_id))
  const exceptionReceipts = receipts.filter((receipt) => receipt.state === 'Exception')

  return <section className="card cod-finance-workspace" aria-labelledby="cod-finance-title">
    <div className="section-heading">
      <div><span className="eyebrow">Finance Gate · T236</span><h2 id="cod-finance-title">COD &amp; Finance</h2><p>Manage the order-level COD obligation, parcel allocation, collection receipt and exception resolution through authoritative commands.</p></div>
      <span className="check">Operations / Admin</span>
    </div>

    <div className="form-row">
      <label>Order number<input value={orderNumber} onChange={(event) => setOrderNumber(event.target.value)} placeholder="e.g. ORD-000076" /></label>
      <button className="secondary-button" type="button" onClick={() => void loadOrder(orderNumber.trim())} disabled={!orderNumber.trim() || loading || working}>{loading ? 'Loading…' : 'Resolve order'}</button>
    </div>

    {error && <p className="form-error" role="alert">{error}</p>}
    {message && <p className="form-success" role="status">{message}</p>}

    {order && <div className="dispatch-parcel-panel">
      <div><span className="eyebrow">Order</span><strong>{order.order_number}</strong><small>{order.lifecycle_state}</small></div>
      <div><span className="eyebrow">Original amount</span><strong>AED {Number(order.original_amount).toFixed(2)}</strong></div>
      <div><span className="eyebrow">COD obligation</span><strong>{obligation ? `AED ${Number(obligation.expected_amount).toFixed(2)}` : 'Not created'}</strong><small>{obligation?.state ?? '—'}</small></div>
      <div><span className="eyebrow">Parcels</span><strong>{parcels.length}</strong></div>
    </div>}

    {order && !obligation && <div className="button-group dispatch-actions"><button className="login-button" type="button" onClick={() => void createObligation()} disabled={working}>Create COD obligation</button></div>}

    {order && obligation && <div className="workspace-grid">
      <article className="card">
        <div className="section-heading"><div><span className="eyebrow">Parcel Allocation</span><h3>Allocate COD</h3></div><span className="check">Authoritative amount</span></div>
        <label>Parcel<select value={selectedParcelId} onChange={(event) => setSelectedParcelId(event.target.value)} disabled={working}><option value="">Select parcel</option>{unallocatedParcels.map((parcel) => <option key={parcel.id} value={parcel.id}>{parcel.parcel_number} · {parcel.state}</option>)}</select></label>
        <label>Expected COD amount (AED)<input type="number" min="0" step="0.01" value={allocationAmount} onChange={(event) => setAllocationAmount(event.target.value)} /></label>
        <button className="login-button" type="button" onClick={() => void allocate()} disabled={working || !selectedParcelId || !allocationAmount}>Allocate COD</button>
      </article>

      <article className="card">
        <div className="section-heading"><div><span className="eyebrow">Receipt Entry</span><h3>Record Collection</h3></div><span className="check">Snapshot protected</span></div>
        <label>Allocated parcel<select value={receiptParcelId} onChange={(event) => setReceiptParcelId(event.target.value)} disabled={working}><option value="">Select parcel</option>{receiptableAllocations.map((item) => <option key={item.parcel_id} value={item.parcel_id}>{item.parcels?.parcel_number ?? item.parcel_id} · Expected AED {Number(item.expected_amount).toFixed(2)}</option>)}</select></label>
        <label>Received amount (AED)<input type="number" min="0" step="0.01" value={receivedAmount} onChange={(event) => setReceivedAmount(event.target.value)} /></label>
        <button className="login-button" type="button" onClick={() => void recordReceipt()} disabled={working || !receiptParcelId || !receivedAmount}>Record COD receipt</button>
      </article>
    </div>}

    {receipts.length > 0 && <div className="orders-table-wrap">
      <h3>COD Receipts</h3>
      <table className="orders-table"><thead><tr><th>Parcel</th><th>Expected</th><th>Received</th><th>State</th><th>Received at</th></tr></thead>
      <tbody>{receipts.map((receipt) => <tr key={receipt.id}><td>{parcels.find((parcel) => parcel.id === receipt.parcel_id)?.parcel_number ?? receipt.parcel_id}</td><td>AED {Number(receipt.expected_amount_snapshot).toFixed(2)}</td><td>AED {Number(receipt.received_amount).toFixed(2)}</td><td><span className="state-pill">{receipt.state}</span></td><td>{new Date(receipt.received_at).toLocaleString()}</td></tr>)}</tbody></table>
    </div>}

    {exceptionReceipts.length > 0 && isAdmin && <div className="card">
      <div className="section-heading"><div><span className="eyebrow">Admin Exception Resolution</span><h3>Resolve COD variance</h3></div><span className="check">Admin only</span></div>
      <label>Exception receipt<select value={exceptionId} onChange={(event) => setExceptionId(event.target.value)} disabled={working}><option value="">Select exception</option>{exceptionReceipts.map((receipt) => <option key={receipt.id} value={receipt.id}>{parcels.find((parcel) => parcel.id === receipt.parcel_id)?.parcel_number ?? receipt.parcel_id} · variance AED {(Number(receipt.received_amount)-Number(receipt.expected_amount_snapshot)).toFixed(2)}</option>)}</select></label>
      <label>Resolution reason<input value={exceptionReason} onChange={(event) => setExceptionReason(event.target.value)} maxLength={500} /></label>
      <button className="login-button" type="button" onClick={() => void resolveException()} disabled={working || !exceptionId || !exceptionReason.trim()}>Resolve COD exception</button>
    </div>}

    {isAdmin && reconciliation && <div className="card">
      <div className="section-heading"><div><span className="eyebrow">Admin Reconciliation</span><h3>COD / financial reconciliation</h3></div><span className="check">{reconciliation.reconciliation_state}</span></div>
      <div className="metrics">
        <article><span className="eyebrow">Original</span><strong>AED {Number(reconciliation.original_amount).toFixed(2)}</strong></article>
        <article><span className="eyebrow">Effective</span><strong>AED {Number(reconciliation.effective_amount).toFixed(2)}</strong></article>
        <article><span className="eyebrow">COD expected</span><strong>AED {Number(reconciliation.cod_expected_amount).toFixed(2)}</strong></article>
        <article><span className="eyebrow">Received</span><strong>AED {Number(reconciliation.received_amount).toFixed(2)}</strong></article>
        <article><span className="eyebrow">Outstanding</span><strong>AED {Number(reconciliation.outstanding_amount).toFixed(2)}</strong></article>
        <article><span className="eyebrow">Variance</span><strong>AED {Number(reconciliation.receipt_variance).toFixed(2)}</strong></article>
      </div>
    </div>}

    {order && allocations.length > 0 && <div className="orders-table-wrap">
      <h3>COD Allocations</h3>
      <table className="orders-table"><thead><tr><th>Parcel</th><th>Expected</th><th>State</th></tr></thead>
      <tbody>{allocations.map((item) => <tr key={item.id}><td>{item.parcels?.parcel_number ?? item.parcel_id}</td><td>AED {Number(item.expected_amount).toFixed(2)}</td><td>{item.parcels?.state ?? '—'}</td></tr>)}</tbody></table>
    </div>}
  </section>
}
