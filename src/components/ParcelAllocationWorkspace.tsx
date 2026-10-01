import { useCallback, useEffect, useMemo, useState } from 'react'
import { listOrders } from '../lib/commands'
import {
  allocateParcelItem,
  allocateParcelItemsSplit,
  cancelParcel,
  correctParcelAllocation,
  createParcel,
} from '../lib/parcelCommands'

type Props = { accessToken: string }

type Parcel = {
  id: string
  state: string
  shipper_id?: string | null
  tracking_id?: string | null
}

type Item = { id: string; line_no: number; description: string; quantity: number }

type Order = {
  id: string
  order_number: string
  lifecycle_state: string
  order_items?: Item[]
  parcels?: Parcel[]
}

export function ParcelAllocationWorkspace({ accessToken }: Props) {
  const [orders, setOrders] = useState<Order[]>([])
  const [search, setSearch] = useState('')
  const [selectedOrderId, setSelectedOrderId] = useState('')
  const [selectedParcelId, setSelectedParcelId] = useState('')
  const [selectedItemId, setSelectedItemId] = useState('')
  const [quantity, setQuantity] = useState('1')
  const [correctionQuantity, setCorrectionQuantity] = useState('')
  const [lastParcelItemId, setLastParcelItemId] = useState('')
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    setError('')
    try {
      const result = await listOrders(accessToken, { page: 1, pageSize: 100, search })
      setOrders(result.orders as unknown as Order[])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load orders')
    }
  }, [accessToken, search])


  useEffect(() => { const timer = window.setTimeout(() => { void load() }, 0); return () => window.clearTimeout(timer) }, [load])

  const selectedOrder = orders.find((order) => order.id === selectedOrderId)
  const parcels = selectedOrder?.parcels ?? []
  const items = selectedOrder?.order_items ?? []
  const selectedParcel = parcels.find((parcel) => parcel.id === selectedParcelId)

  const allocationReady = Boolean(selectedParcelId && selectedItemId && Number.isInteger(Number(quantity)) && Number(quantity) > 0)
  const canCorrect = Boolean(lastParcelItemId && correctionQuantity && Number.isInteger(Number(correctionQuantity)) && Number(correctionQuantity) >= 0)

  function selectOrder(id: string) {
    setSelectedOrderId(id)
    const order = orders.find((row) => row.id === id)
    setSelectedParcelId(order?.parcels?.[0]?.id ?? '')
    setSelectedItemId(order?.order_items?.[0]?.id ?? '')
    setLastParcelItemId('')
    setMessage('')
  }

  async function run(action: () => Promise<unknown>, success: string) {
    setBusy(true); setError(''); setMessage('')
    try { await action(); setMessage(success); await load() }
    catch (e) { setError(e instanceof Error ? e.message : 'Operation failed') }
    finally { setBusy(false) }
  }

  async function handleCreateParcel() {
    if (!selectedOrderId) return
    await run(
      () => createParcel(accessToken, { p_order_id: selectedOrderId, p_idempotency_key: crypto.randomUUID() }),
      'Parcel created successfully.',
    )
  }

  async function handleAllocate() {
    if (!allocationReady) return
    await run(
      () => allocateParcelItem(accessToken, {
        p_parcel_id: selectedParcelId,
        p_order_item_id: selectedItemId,
        p_quantity: Number(quantity),
        p_idempotency_key: crypto.randomUUID(),
      }),
      'Allocation recorded successfully.',
      (result) => { const row = result[0]; if (row?.parcel_item_id) setLastParcelItemId(row.parcel_item_id) },
    )
  }

  async function handleSplit() {
    if (!allocationReady) return
    const secondParcelId = window.prompt('Enter the second parcel ID for the split allocation')
    if (!secondParcelId || secondParcelId === selectedParcelId) return
    const secondQuantity = Number(window.prompt('Enter the quantity for the second parcel') ?? '')
    if (!Number.isInteger(secondQuantity) || secondQuantity <= 0) return
    await run(
      () => allocateParcelItemsSplit(accessToken, {
        p_order_item_id: selectedItemId,
        p_allocations: [{ parcel_id: selectedParcelId, quantity: Number(quantity) }, { parcel_id: secondParcelId, quantity: secondQuantity }],
        p_idempotency_key: crypto.randomUUID(),
      }),
      'Split allocation recorded successfully.',
      (result) => { const row = result[0]; if (row?.parcel_item_id) setLastParcelItemId(row.parcel_item_id) },
    )
  }

  async function handleCorrect() {
    if (!canCorrect) return
    if (!lastParcelItemId) return
    await run(
      () => correctParcelAllocation(accessToken, {
        p_parcel_item_id: lastParcelItemId,
        p_corrected_quantity: Number(correctionQuantity),
        p_idempotency_key: crypto.randomUUID(),
      }),
      'Allocation correction submitted.',
      () => setLastParcelItemId(''),
    )
  }

  async function handleCancel() {
    if (!selectedParcelId) return
    await run(
      () => cancelParcel(accessToken, { p_parcel_id: selectedParcelId, p_idempotency_key: crypto.randomUUID() }),
      'Parcel cancellation submitted.',
    )
  }

  const filteredOrders = useMemo(() => orders, [orders])

  return (
    <section className="parcel-workspace" aria-labelledby="parcel-workspace-title">
      <div className="workspace-toolbar">
        <div>
          <span className="eyebrow">Parcel operations</span>
          <h2 id="parcel-workspace-title">Parcels &amp; Allocation</h2>
          <p>Existing parcel creation, allocation and pre-dispatch correction workflows.</p>
        </div>
        <button className="secondary-button" type="button" onClick={() => void load()} disabled={busy}>Refresh</button>
      </div>

      <div className="parcel-grid">
        <article className="card parcel-order-list">
          <div className="section-heading"><div><strong>Orders</strong><p className="form-note">Select an order to manage its existing parcels.</p></div></div>
          <div className="parcel-search"><label htmlFor="parcel-order-search">Search<input id="parcel-order-search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Order number, customer or item" /></label></div>
          {filteredOrders.length === 0 ? <p className="empty-state">No matching orders.</p> : (
            <div className="parcel-orders" role="list">
              {filteredOrders.map((order) => (
                <button key={order.id} type="button" className={order.id === selectedOrderId ? 'parcel-order selected' : 'parcel-order'} onClick={() => selectOrder(order.id)}>
                  <strong>{order.order_number}</strong><span>{order.lifecycle_state}</span><span>{order.parcels?.length ?? 0} parcel{(order.parcels?.length ?? 0) === 1 ? '' : 's'}</span>
                </button>
              ))}
            </div>
          )}
        </article>

        <article className="card parcel-detail">
          {!selectedOrder ? <div className="empty-state"><strong>Select an order</strong><p>Parcel details and allocation controls will appear here.</p></div> : (
            <>
              <div className="section-heading">
                <div><span className="eyebrow">Selected order</span><h3>{selectedOrder.order_number}</h3></div>
                <button className="secondary-button" type="button" onClick={() => void handleCreateParcel()} disabled={busy}>Create Parcel</button>
              </div>

              <div className="parcel-control-grid">
                <label>Parcel
                  <select value={selectedParcelId} onChange={(e) => setSelectedParcelId(e.target.value)}>
                    <option value="">Select parcel</option>
                    {parcels.map((parcel) => <option key={parcel.id} value={parcel.id}>{parcel.id.slice(0, 8)} · {parcel.state}</option>)}
                  </select>
                </label>
                <label>Order item
                  <select value={selectedItemId} onChange={(e) => setSelectedItemId(e.target.value)}>
                    <option value="">Select item</option>
                    {items.map((item) => <option key={item.id} value={item.id}>#{item.line_no} · {item.description} · Qty {item.quantity}</option>)}
                  </select>
                </label>
              </div>

              <div className="parcel-summary">
                <span><strong>State</strong>{selectedParcel?.state ?? '—'}</span>
                <span><strong>Tracking</strong>{selectedParcel?.tracking_id ?? 'Not assigned'}</span>
              </div>

              <div className="parcel-action-panel">
                <div><strong>Allocate quantity</strong><p className="form-note">Uses the existing allocation command; server-side invariants remain authoritative.</p></div>
                <label>Quantity<input type="number" min="1" step="1" value={quantity} onChange={(e) => setQuantity(e.target.value)} /></label>
                <div className="parcel-actions">
                  <button className="login-button" type="button" onClick={() => void handleAllocate()} disabled={busy || !allocationReady}>Allocate</button>
                  <button className="secondary-button" type="button" onClick={() => void handleSplit()} disabled={busy || !allocationReady}>Split Allocation</button>
                </div>
              </div>

              <div className="parcel-action-panel">
                <div><strong>Correct allocation</strong><p className="form-note">Only the existing correction command is invoked.</p></div>
                <label>Corrected quantity<input type="number" min="0" step="1" value={correctionQuantity} onChange={(e) => setCorrectionQuantity(e.target.value)} /></label>
                <button className="secondary-button" type="button" onClick={() => void handleCorrect()} disabled={busy || !canCorrect}>Correct Allocation</button>
              </div>

              <div className="parcel-danger-zone">
                <div><strong>Cancel prepared parcel</strong><p className="form-note">The backend determines whether cancellation is permitted.</p></div>
                <button className="remove-button" type="button" onClick={() => void handleCancel()} disabled={busy || !selectedParcelId}>Cancel Parcel</button>
              </div>
            </>
          )}
          {message && <p className="form-success" role="status">{message}</p>}
          {error && <p className="form-error" role="alert">{error}</p>}
        </article>
      </div>
    </section>
  )
}
