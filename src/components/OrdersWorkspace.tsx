import { useEffect, useState } from 'react'
import { confirmOrder, getOrderTimeline, listOrders, updateOrder, type OrderItemRow, type OrderListRow, type OrderTimelineEvent } from '../lib/commands'
import { normalizeAedAmount } from '../lib/money'

type Props = { accessToken: string }
type EditableItem = Pick<OrderItemRow, 'description' | 'quantity'>
const PAGE_SIZE = 25

function toEditorState(order: OrderListRow) {
  return { customerName: order.customers?.name ?? '', phone: order.customers?.phone ?? '', address: order.customers?.address ?? '', city: order.customers?.city ?? '', amount: Number(order.original_amount).toFixed(2), notes: order.notes ?? '', items: order.order_items.map((item) => ({ description: item.description, quantity: item.quantity })) }
}
function timelineLabel(event: OrderTimelineEvent) {
  switch (event.event_type) { case 'OrderCreated': return 'Order created'; case 'OrderUpdated': return 'Order updated'; case 'OrderConfirmed': return 'Order confirmed'; case 'OrderCancelled': return 'Order cancelled'; default: return event.event_type }
}

export function OrdersWorkspace({ accessToken }: Props) {
  const [orders, setOrders] = useState<OrderListRow[]>([])
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editing, setEditing] = useState<OrderListRow | null>(null)
  const [draft, setDraft] = useState<ReturnType<typeof toEditorState> | null>(null)
  const [saveLoading, setSaveLoading] = useState(false)
  const [saveMessage, setSaveMessage] = useState('')
  const [confirmingOrderId, setConfirmingOrderId] = useState<string | null>(null)
  const [confirmMessage, setConfirmMessage] = useState('')
  const [timelineOrder, setTimelineOrder] = useState<OrderListRow | null>(null)
  const [timeline, setTimeline] = useState<OrderTimelineEvent[]>([])
  const [timelineLoading, setTimelineLoading] = useState(false)
  const [timelineError, setTimelineError] = useState('')

  async function refresh(targetPage = page) {
    setLoading(true); setError('')
    try {
      const result = await listOrders(accessToken, { page: targetPage, pageSize: PAGE_SIZE })
      setOrders(result.orders); setPage(result.page); setHasMore(result.hasMore)
    } catch (requestError) { setError(requestError instanceof Error ? requestError.message : 'Unable to load orders') }
    finally { setLoading(false) }
  }
  function startEditing(order: OrderListRow) { setEditing(order); setDraft(toEditorState(order)); setSaveMessage('') }
  function closeEditor() { if (saveLoading) return; setEditing(null); setDraft(null); setSaveMessage('') }
  function updateItem(index: number, field: keyof EditableItem, value: string) { setDraft((current) => current ? { ...current, items: current.items.map((item, itemIndex) => itemIndex === index ? { ...item, [field]: field === 'quantity' ? Number(value) : value } : item) } : current) }
  function addItem() { setDraft((current) => current ? { ...current, items: [...current.items, { description: '', quantity: 1 }] } : current) }
  function removeItem(index: number) { setDraft((current) => current && current.items.length > 1 ? { ...current, items: current.items.filter((_, itemIndex) => itemIndex !== index) } : current) }
  async function saveDraft() {
    if (!editing || !draft) return
    setSaveLoading(true); setSaveMessage('')
    try {
      const items = draft.items.map((item) => ({ description: item.description.trim(), quantity: Number(item.quantity) }))
      if (!items.every((item) => item.description && Number.isInteger(item.quantity) && item.quantity > 0)) throw new Error('Enter a description and positive whole quantity for every item')
      const normalizedAmount = normalizeAedAmount(draft.amount)
      const result = await updateOrder(accessToken, { p_order_id: editing.id, p_customer_name: draft.customerName.trim(), p_phone: draft.phone.trim(), p_address: draft.address.trim() || null, p_city: draft.city.trim() || null, p_original_amount: normalizedAmount, p_items: items, p_notes: draft.notes.trim() || null, p_idempotency_key: crypto.randomUUID() })
      const order = result[0]; if (!order) throw new Error('The update completed without returning the order')
      setSaveMessage(`Order ${order.order_number} updated as Draft.`); await refresh(page); setEditing(null); setDraft(null)
    } catch (updateError) { setSaveMessage(updateError instanceof Error ? updateError.message : 'Order update failed') }
    finally { setSaveLoading(false) }
  }
  async function handleConfirm(order: OrderListRow) {
    if (order.lifecycle_state !== 'Draft' || confirmingOrderId) return
    setConfirmingOrderId(order.id); setConfirmMessage('')
    try {
      const result = await confirmOrder(accessToken, { p_order_id: order.id, p_idempotency_key: crypto.randomUUID() }); const confirmed = result[0]
      if (!confirmed) throw new Error('The confirmation completed without returning the order')
      setConfirmMessage(`Order ${confirmed.order_number} confirmed.`); await refresh(page)
    } catch (confirmError) { setConfirmMessage(confirmError instanceof Error ? confirmError.message : 'Order confirmation failed') }
    finally { setConfirmingOrderId(null) }
  }
  async function openTimeline(order: OrderListRow) {
    setTimelineOrder(order); setTimeline([]); setTimelineError(''); setTimelineLoading(true)
    try { setTimeline(await getOrderTimeline(accessToken, order.id)) }
    catch (requestError) { setTimelineError(requestError instanceof Error ? requestError.message : 'Unable to load order timeline') }
    finally { setTimelineLoading(false) }
  }
  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try {
        const result = await listOrders(accessToken, { page: 1, pageSize: PAGE_SIZE })
        if (!cancelled) { setOrders(result.orders); setPage(result.page); setHasMore(result.hasMore); setError('') }
      } catch (requestError) { if (!cancelled) setError(requestError instanceof Error ? requestError.message : 'Unable to load orders') }
      finally { if (!cancelled) setLoading(false) }
    }
    setPage(1); void load(); return () => { cancelled = true }
  }, [accessToken])

  return (
    <section className="card orders-workspace" aria-labelledby="orders-title">
      <div className="section-heading"><div><span className="eyebrow">Orders Workspace</span><h2 id="orders-title">Recent Orders</h2><p>Draft orders can be edited or confirmed. Confirmed and later states are locked by the command boundary.</p></div><button className="secondary-button" type="button" onClick={() => void refresh(page)} disabled={loading || confirmingOrderId !== null}>{loading ? 'Refreshing…' : 'Refresh'}</button></div>
      {error && <p className="form-error" role="alert">{error}</p>}
      {confirmMessage && <p className={confirmMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{confirmMessage}</p>}
      {!error && loading && <p className="form-note">Loading orders…</p>}
      {!error && !loading && orders.length === 0 && <p className="empty-state">No orders on this page.</p>}
      {!error && !loading && orders.length > 0 && <>
        <div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Order</th><th>Customer</th><th>State</th><th>Amount</th><th>Created</th><th>Action</th></tr></thead><tbody>
          {orders.map((order) => <tr key={order.id}><td><strong>{order.order_number}</strong></td><td><span>{order.customers?.name ?? '—'}</span><small>{order.customers?.phone ?? ''}</small></td><td><span className="state-pill">{order.lifecycle_state}</span></td><td>AED {Number(order.original_amount).toFixed(2)}</td><td>{new Date(order.created_at).toLocaleString()}</td><td><div className="button-group"><button className="secondary-button" type="button" onClick={() => void openTimeline(order)} disabled={confirmingOrderId !== null}>Timeline</button>{order.lifecycle_state === 'Draft' ? <><button className="secondary-button" type="button" onClick={() => startEditing(order)} disabled={confirmingOrderId !== null}>Edit</button><button className="login-button" type="button" onClick={() => void handleConfirm(order)} disabled={confirmingOrderId !== null}>{confirmingOrderId === order.id ? 'Confirming…' : 'Confirm'}</button></> : <span className="form-note">Locked</span>}</div></td></tr>)}
        </tbody></table></div>
        <div className="section-heading" aria-label="Orders pagination"><span className="form-note">Page {page} · {orders.length} orders shown</span><div className="button-group"><button className="secondary-button" type="button" onClick={() => void refresh(page - 1)} disabled={loading || page === 1 || confirmingOrderId !== null}>Previous</button><button className="secondary-button" type="button" onClick={() => void refresh(page + 1)} disabled={loading || !hasMore || confirmingOrderId !== null}>Next</button></div></div>
      </>}

      {timelineOrder && <div className="order-editor" role="dialog" aria-modal="true" aria-labelledby="timeline-title"><div className="section-heading"><div><span className="eyebrow">Order Timeline</span><h3 id="timeline-title">{timelineOrder.order_number}</h3><p>Immutable operational events are shown newest first.</p></div><button className="secondary-button" type="button" onClick={() => setTimelineOrder(null)} disabled={timelineLoading}>Close</button></div>{timelineError && <p className="form-error" role="alert">{timelineError}</p>}{timelineLoading && <p className="form-note">Loading timeline…</p>}{!timelineLoading && !timelineError && timeline.length === 0 && <p className="empty-state">No timeline events recorded.</p>}{!timelineLoading && !timelineError && timeline.length > 0 && <div className="timeline-list">{timeline.map((event) => <article className="timeline-item" key={event.id}><strong>{timelineLabel(event)}</strong><time dateTime={event.event_time}>{new Date(event.event_time).toLocaleString()}</time>{event.parcel_id && <small>Parcel: {event.parcel_id}</small>}{event.notes && <p>{event.notes}</p>}</article>)}</div>}</div>}
      {editing && draft && <div className="order-editor" role="dialog" aria-modal="true" aria-labelledby="edit-order-title"><div className="section-heading"><div><span className="eyebrow">Draft Order</span><h3 id="edit-order-title">Edit {editing.order_number}</h3><p>Changes are saved atomically and are allowed only while the order remains Draft.</p></div><button className="secondary-button" type="button" onClick={closeEditor} disabled={saveLoading}>Cancel</button></div><div className="order-form"><div className="form-row"><label>Customer name<input value={draft.customerName} onChange={(event) => setDraft({ ...draft, customerName: event.target.value })} required /></label><label>Customer phone<input value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} required /></label></div><div className="form-row"><label>City<input value={draft.city} onChange={(event) => setDraft({ ...draft, city: event.target.value })} /></label><label>Total Order Amount (AED)<input type="number" min="0" step="0.01" inputMode="decimal" value={draft.amount} onChange={(event) => setDraft({ ...draft, amount: event.target.value })} required /></label></div><label>Address<input value={draft.address} onChange={(event) => setDraft({ ...draft, address: event.target.value })} /></label><div className="items-heading"><strong>Order items</strong><button className="secondary-button" type="button" onClick={addItem}>+ Add item</button></div>{draft.items.map((item, index) => <div className="item-row" key={index}><input aria-label={`Edit product description ${index + 1}`} value={item.description} onChange={(event) => updateItem(index, 'description', event.target.value)} required /><input aria-label={`Edit quantity ${index + 1}`} type="number" min="1" step="1" value={item.quantity} onChange={(event) => updateItem(index, 'quantity', event.target.value)} required /><button className="remove-button" type="button" onClick={() => removeItem(index)} disabled={draft.items.length === 1}>Remove</button></div>)}<label>Notes<input value={draft.notes} onChange={(event) => setDraft({ ...draft, notes: event.target.value })} /></label><button className="login-button" type="button" onClick={() => void saveDraft()} disabled={saveLoading}>{saveLoading ? 'Saving changes…' : 'Save Draft Changes'}</button>{saveMessage && <p className={saveMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{saveMessage}</p>}</div></div>}
    </section>
  )
}
