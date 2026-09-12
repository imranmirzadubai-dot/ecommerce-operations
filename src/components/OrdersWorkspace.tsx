import { useEffect, useState } from 'react'
import { listOrders, updateOrder, type OrderItemRow, type OrderListRow } from '../lib/commands'
import { normalizeAedAmount } from '../lib/money'

type Props = { accessToken: string }
type EditableItem = Pick<OrderItemRow, 'description' | 'quantity'>

function toEditorState(order: OrderListRow) {
  return {
    customerName: order.customers?.name ?? '',
    phone: order.customers?.phone ?? '',
    address: order.customers?.address ?? '',
    city: order.customers?.city ?? '',
    amount: Number(order.original_amount).toFixed(2),
    notes: order.notes ?? '',
    items: order.order_items.map((item) => ({ description: item.description, quantity: item.quantity })),
  }
}

export function OrdersWorkspace({ accessToken }: Props) {
  const [orders, setOrders] = useState<OrderListRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editing, setEditing] = useState<OrderListRow | null>(null)
  const [draft, setDraft] = useState<ReturnType<typeof toEditorState> | null>(null)
  const [saveLoading, setSaveLoading] = useState(false)
  const [saveMessage, setSaveMessage] = useState('')

  async function refresh() {
    setLoading(true)
    setError('')
    try {
      setOrders(await listOrders(accessToken))
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to load orders')
    } finally {
      setLoading(false)
    }
  }

  function startEditing(order: OrderListRow) {
    setEditing(order)
    setDraft(toEditorState(order))
    setSaveMessage('')
  }

  function closeEditor() {
    if (saveLoading) return
    setEditing(null)
    setDraft(null)
    setSaveMessage('')
  }

  function updateItem(index: number, field: keyof EditableItem, value: string) {
    setDraft((current) => current ? { ...current, items: current.items.map((item, itemIndex) => itemIndex === index ? { ...item, [field]: field === 'quantity' ? Number(value) : value } : item) } : current)
  }

  function addItem() {
    setDraft((current) => current ? { ...current, items: [...current.items, { description: '', quantity: 1 }] } : current)
  }

  function removeItem(index: number) {
    setDraft((current) => current && current.items.length > 1 ? { ...current, items: current.items.filter((_, itemIndex) => itemIndex !== index) } : current)
  }

  async function saveDraft() {
    if (!editing || !draft) return
    setSaveLoading(true)
    setSaveMessage('')
    try {
      const items = draft.items.map((item) => ({ description: item.description.trim(), quantity: Number(item.quantity) }))
      if (!items.every((item) => item.description && Number.isInteger(item.quantity) && item.quantity > 0)) {
        throw new Error('Enter a description and positive whole quantity for every item')
      }
      const normalizedAmount = normalizeAedAmount(draft.amount)
      const result = await updateOrder(accessToken, {
        p_order_id: editing.id,
        p_customer_name: draft.customerName.trim(),
        p_phone: draft.phone.trim(),
        p_address: draft.address.trim() || null,
        p_city: draft.city.trim() || null,
        p_original_amount: normalizedAmount,
        p_items: items,
        p_notes: draft.notes.trim() || null,
        p_idempotency_key: crypto.randomUUID(),
      })
      const order = result[0]
      if (!order) throw new Error('The update completed without returning the order')
      setSaveMessage(`Order ${order.order_number} updated as Draft.`)
      await refresh()
      setEditing(null)
      setDraft(null)
    } catch (updateError) {
      setSaveMessage(updateError instanceof Error ? updateError.message : 'Order update failed')
    } finally {
      setSaveLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try {
        const nextOrders = await listOrders(accessToken)
        if (!cancelled) { setOrders(nextOrders); setError('') }
      } catch (requestError) {
        if (!cancelled) setError(requestError instanceof Error ? requestError.message : 'Unable to load orders')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void load()
    return () => { cancelled = true }
  }, [accessToken])

  return (
    <section className="card orders-workspace" aria-labelledby="orders-title">
      <div className="section-heading">
        <div><span className="eyebrow">Orders Workspace</span><h2 id="orders-title">Recent Orders</h2><p>Draft orders can be edited before confirmation. Confirmed and later states are locked by the command boundary.</p></div>
        <button className="secondary-button" type="button" onClick={() => void refresh()} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh'}</button>
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      {!error && loading && <p className="form-note">Loading orders…</p>}
      {!error && !loading && orders.length === 0 && <p className="empty-state">No orders yet. Create the first Draft Order above.</p>}
      {!error && !loading && orders.length > 0 && (
        <div className="orders-table-wrap">
          <table className="orders-table"><thead><tr><th>Order</th><th>Customer</th><th>State</th><th>Amount</th><th>Created</th><th>Action</th></tr></thead><tbody>
            {orders.map((order) => <tr key={order.id}><td><strong>{order.order_number}</strong></td><td><span>{order.customers?.name ?? '—'}</span><small>{order.customers?.phone ?? ''}</small></td><td><span className="state-pill">{order.lifecycle_state}</span></td><td>AED {Number(order.original_amount).toFixed(2)}</td><td>{new Date(order.created_at).toLocaleString()}</td><td>{order.lifecycle_state === 'Draft' ? <button className="secondary-button" type="button" onClick={() => startEditing(order)}>Edit</button> : <span className="form-note">Locked</span>}</td></tr>)}
          </tbody></table>
        </div>
      )}

      {editing && draft && (
        <div className="order-editor" role="dialog" aria-modal="true" aria-labelledby="edit-order-title">
          <div className="section-heading"><div><span className="eyebrow">Draft Order</span><h3 id="edit-order-title">Edit {editing.order_number}</h3><p>Changes are saved atomically and are allowed only while the order remains Draft.</p></div><button className="secondary-button" type="button" onClick={closeEditor} disabled={saveLoading}>Cancel</button></div>
          <div className="order-form">
            <div className="form-row"><label>Customer name<input value={draft.customerName} onChange={(event) => setDraft({ ...draft, customerName: event.target.value })} required /></label><label>Customer phone<input value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} required /></label></div>
            <div className="form-row"><label>City<input value={draft.city} onChange={(event) => setDraft({ ...draft, city: event.target.value })} /></label><label>Total Order Amount (AED)<input type="number" min="0" step="0.01" inputMode="decimal" value={draft.amount} onChange={(event) => setDraft({ ...draft, amount: event.target.value })} required /></label></div>
            <label>Address<input value={draft.address} onChange={(event) => setDraft({ ...draft, address: event.target.value })} /></label>
            <div className="items-heading"><strong>Order items</strong><button className="secondary-button" type="button" onClick={addItem}>+ Add item</button></div>
            {draft.items.map((item, index) => <div className="item-row" key={index}><input aria-label={`Edit product description ${index + 1}`} value={item.description} onChange={(event) => updateItem(index, 'description', event.target.value)} required /><input aria-label={`Edit quantity ${index + 1}`} type="number" min="1" step="1" value={item.quantity} onChange={(event) => updateItem(index, 'quantity', event.target.value)} required /><button className="remove-button" type="button" onClick={() => removeItem(index)} disabled={draft.items.length === 1}>Remove</button></div>)}
            <label>Notes<input value={draft.notes} onChange={(event) => setDraft({ ...draft, notes: event.target.value })} /></label>
            <button className="login-button" type="button" onClick={() => void saveDraft()} disabled={saveLoading}>{saveLoading ? 'Saving changes…' : 'Save Draft Changes'}</button>
            {saveMessage && <p className={saveMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{saveMessage}</p>}
          </div>
        </div>
      )}
    </section>
  )
}
