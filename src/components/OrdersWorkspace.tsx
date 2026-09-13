import { useEffect, useState } from 'react'
import { confirmOrder, getOrderTimeline, listOrders, updateOrder, type OrderItemRow, type OrderListRow, type OrderTimelineEvent } from '../lib/commands'
import { normalizeAedAmount } from '../lib/money'

type Props = { accessToken: string }
type EditableItem = Pick<OrderItemRow, 'description' | 'quantity'>
const PAGE_SIZE = 25
const LIFECYCLE_OPTIONS = ['', 'Draft', 'Confirmed', 'Active', 'Completed', 'Cancelled']
const PARCEL_OPTIONS = ['', 'Prepared', 'Dispatched', 'In Transit', 'NDR', 'Delivered', 'RTO', 'Lost', 'Damaged', 'Cancelled']
const COD_OPTIONS = ['', 'Outstanding', 'Partially Received', 'Received', 'Exception', 'Voided', 'Closed']
const DATE_VIEWS = ['All dates', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Custom'] as const
type DateView = typeof DATE_VIEWS[number]

function isoDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}
function getDateRange(view: Exclude<DateView, 'All dates' | 'Custom'>, now = new Date()) {
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const start = new Date(end)
  if (view === 'Yesterday') start.setDate(start.getDate() - 1)
  if (view === 'Last 7 Days') start.setDate(start.getDate() - 6)
  if (view === 'Last 30 Days') start.setDate(start.getDate() - 29)
  return { dateFrom: isoDate(start), dateTo: isoDate(view === 'Yesterday' ? start : end) }
}
function toEditorState(order: OrderListRow) {
  return { customerName: order.customers?.name ?? '', phone: order.customers?.phone ?? '', address: order.customers?.address ?? '', city: order.customers?.city ?? '', amount: Number(order.original_amount).toFixed(2), notes: order.notes ?? '', items: order.order_items.map((item) => ({ description: item.description, quantity: item.quantity })) }
}
function timelineLabel(event: OrderTimelineEvent) {
  switch (event.event_type) { case 'OrderCreated': return 'Order created'; case 'OrderUpdated': return 'Order updated'; case 'OrderConfirmed': return 'Order confirmed'; case 'OrderCancelled': return 'Order cancelled'; default: return event.event_type }
}
function csvCell(value: string | number | null | undefined) {
  const text = value == null ? '' : String(value)
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}
function downloadOrdersCsv(orders: OrderListRow[]) {
  const header = ['Order', 'Customer', 'Phone', 'Lifecycle State', 'Amount (AED)', 'Order Date', 'Items']
  const rows = orders.map((order) => [
    order.order_number,
    order.customers?.name ?? '',
    order.customers?.phone ?? '',
    order.lifecycle_state,
    Number(order.original_amount).toFixed(2),
    order.order_date,
    order.order_items.map((item) => `${item.description} x${item.quantity}`).join('; '),
  ])
  const csv = '\uFEFF' + [header, ...rows].map((row) => row.map(csvCell).join(',')).join('\r\n') + '\r\n'
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = `orders-page-${isoDate(new Date())}.csv`
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(url)
}

export function OrdersWorkspace({ accessToken }: Props) {
  const [orders, setOrders] = useState<OrderListRow[]>([])
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(false)
  const [search, setSearch] = useState('')
  const [searchInput, setSearchInput] = useState('')
  const [lifecycleState, setLifecycleState] = useState('')
  const [parcelState, setParcelState] = useState('')
  const [codState, setCodState] = useState('')
  const [dateView, setDateView] = useState<DateView>('All dates')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
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

  async function refresh(targetPage = page, targetSearch = search, targetLifecycle = lifecycleState, targetParcel = parcelState, targetCod = codState, targetDateFrom = dateFrom, targetDateTo = dateTo) {
    setLoading(true); setError('')
    try {
      const result = await listOrders(accessToken, { page: targetPage, pageSize: PAGE_SIZE, search: targetSearch, lifecycleState: targetLifecycle, parcelState: targetParcel, codState: targetCod, dateFrom: targetDateFrom, dateTo: targetDateTo })
      setOrders(result.orders); setPage(result.page); setHasMore(result.hasMore); setSearch(result.search); setLifecycleState(targetLifecycle); setParcelState(targetParcel); setCodState(targetCod); setDateFrom(targetDateFrom); setDateTo(targetDateTo)
    } catch (requestError) { setError(requestError instanceof Error ? requestError.message : 'Unable to load orders') }
    finally { setLoading(false) }
  }
  function submitSearch(event: React.FormEvent) { event.preventDefault(); void refresh(1, searchInput.trim()) }
  function applyFilters() { void refresh(1, search, lifecycleState, parcelState, codState, dateFrom, dateTo) }
  function clearFilters() { setLifecycleState(''); setParcelState(''); setCodState(''); void refresh(1, search, '', '', '', dateFrom, dateTo) }
  function clearSearch() { setSearchInput(''); void refresh(1, '', lifecycleState, parcelState, codState, dateFrom, dateTo) }
  function applyDateView(view: DateView) {
    setDateView(view)
    if (view === 'All dates') { setDateFrom(''); setDateTo(''); void refresh(1, search, lifecycleState, parcelState, codState, '', ''); return }
    if (view === 'Custom') return
    const range = getDateRange(view)
    setDateFrom(range.dateFrom); setDateTo(range.dateTo)
    void refresh(1, search, lifecycleState, parcelState, codState, range.dateFrom, range.dateTo)
  }
  function applyCustomDateRange() {
    if (!dateFrom || !dateTo) { setError('Select both a start date and an end date'); return }
    if (dateFrom > dateTo) { setError('Start date must be on or before end date'); return }
    void refresh(1, search, lifecycleState, parcelState, codState, dateFrom, dateTo)
  }
  function clearDateView() { setDateView('All dates'); setDateFrom(''); setDateTo(''); void refresh(1, search, lifecycleState, parcelState, codState, '', '') }
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
        const result = await listOrders(accessToken, { page: 1, pageSize: PAGE_SIZE, search: '', lifecycleState: '', parcelState: '', codState: '', dateFrom: '', dateTo: '' })
        if (!cancelled) { setOrders(result.orders); setPage(result.page); setHasMore(result.hasMore); setSearch(result.search); setSearchInput(''); setLifecycleState(''); setParcelState(''); setCodState(''); setDateView('All dates'); setDateFrom(''); setDateTo(''); setError('') }
      } catch (requestError) { if (!cancelled) setError(requestError instanceof Error ? requestError.message : 'Unable to load orders') }
      finally { if (!cancelled) setLoading(false) }
    }
    void load(); return () => { cancelled = true }
  }, [accessToken])

  return (
    <section className="card orders-workspace" aria-labelledby="orders-title">
      <div className="section-heading"><div><span className="eyebrow">Orders Workspace</span><h2 id="orders-title">Recent Orders</h2><p>Draft orders can be edited or confirmed. Confirmed and later states are locked by the command boundary.</p></div><div className="button-group"><button className="secondary-button" type="button" onClick={() => void refresh(page)} disabled={loading || confirmingOrderId !== null}>{loading ? 'Refreshing…' : 'Refresh'}</button><button className="secondary-button" type="button" onClick={() => downloadOrdersCsv(orders)} disabled={loading || orders.length === 0}>Export CSV</button></div></div>
      <form className="order-search" role="search" onSubmit={submitSearch}><label htmlFor="order-search-input">Search orders</label><div className="button-group"><input id="order-search-input" value={searchInput} onChange={(event) => setSearchInput(event.target.value)} placeholder="Order ID, customer, phone, address or item" autoComplete="off" /><button className="login-button" type="submit" disabled={loading}>Search</button>{search && <button className="secondary-button" type="button" onClick={clearSearch} disabled={loading}>Clear</button>}</div><small className="form-note">Search runs server-side across Order ID, customer name, phone, address and item description.</small></form>
      <div className="order-filters" aria-label="Order filters"><label>Order state<select value={lifecycleState} onChange={(event) => setLifecycleState(event.target.value)}><option value="">All states</option>{LIFECYCLE_OPTIONS.slice(1).map((value) => <option key={value} value={value}>{value}</option>)}</select></label><label>Parcel / dispatch<select value={parcelState} onChange={(event) => setParcelState(event.target.value)}><option value="">All parcel states</option>{PARCEL_OPTIONS.slice(1).map((value) => <option key={value} value={value}>{value}</option>)}</select></label><label>COD<select value={codState} onChange={(event) => setCodState(event.target.value)}><option value="">All COD states</option>{COD_OPTIONS.slice(1).map((value) => <option key={value} value={value}>{value}</option>)}</select></label><div className="button-group"><button className="login-button" type="button" onClick={applyFilters} disabled={loading}>Apply filters</button><button className="secondary-button" type="button" onClick={clearFilters} disabled={loading || (!lifecycleState && !parcelState && !codState)}>Clear filters</button></div></div>
      <div className="order-date-views" aria-label="Order date views"><label>Date view<select value={dateView} onChange={(event) => applyDateView(event.target.value as DateView)}>{DATE_VIEWS.map((value) => <option key={value} value={value}>{value}</option>)}</select></label>{dateView === 'Custom' && <><label>From<input aria-label="Date from" type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} /></label><label>To<input aria-label="Date to" type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} /></label><button className="login-button" type="button" onClick={applyCustomDateRange} disabled={loading}>Apply dates</button></>}{dateView !== 'All dates' && <button className="secondary-button" type="button" onClick={clearDateView} disabled={loading}>Clear dates</button>}</div>
      {error && <p className="form-error" role="alert">{error}</p>}
      {confirmMessage && <p className={confirmMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{confirmMessage}</p>}
      {!error && loading && <p className="form-note">Loading orders…</p>}
      {!error && !loading && orders.length === 0 && <p className="empty-state">{search ? `No orders matched “${search}”.` : 'No orders on this page.'}</p>}
      {!error && !loading && orders.length > 0 && <>
        <div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Order</th><th>Customer</th><th>State</th><th>Amount</th><th>Date</th><th>Action</th></tr></thead><tbody>
          {orders.map((order) => <tr key={order.id}><td><strong>{order.order_number}</strong></td><td><span>{order.customers?.name ?? '—'}</span><small>{order.customers?.phone ?? ''}</small></td><td><span className="state-pill">{order.lifecycle_state}</span></td><td>AED {Number(order.original_amount).toFixed(2)}</td><td>{order.order_date}</td><td><div className="button-group"><button className="secondary-button" type="button" onClick={() => void openTimeline(order)} disabled={confirmingOrderId !== null}>Timeline</button>{order.lifecycle_state === 'Draft' ? <><button className="secondary-button" type="button" onClick={() => startEditing(order)} disabled={confirmingOrderId !== null}>Edit</button><button className="login-button" type="button" onClick={() => void handleConfirm(order)} disabled={confirmingOrderId !== null}>{confirmingOrderId === order.id ? 'Confirming…' : 'Confirm'}</button></> : <span className="form-note">Locked</span>}</div></td></tr>)}
        </tbody></table></div>
        <div className="section-heading" aria-label="Orders pagination"><span className="form-note">Page {page} · {orders.length} orders shown{search ? ` · Search: ${search}` : ''}{(lifecycleState || parcelState || codState) ? ` · Filters: ${[lifecycleState, parcelState, codState].filter(Boolean).join(', ')}` : ''}{dateFrom || dateTo ? ` · Dates: ${dateFrom || '…'} to ${dateTo || '…'}` : ''}</span><div className="button-group"><button className="secondary-button" type="button" onClick={() => void refresh(page - 1)} disabled={loading || page === 1 || confirmingOrderId !== null}>Previous</button><button className="secondary-button" type="button" onClick={() => void refresh(page + 1)} disabled={loading || !hasMore || confirmingOrderId !== null}>Next</button></div></div>
      </>}

      {timelineOrder && <div className="order-editor" role="dialog" aria-modal="true" aria-labelledby="timeline-title"><div className="section-heading"><div><span className="eyebrow">Order Timeline</span><h3 id="timeline-title">{timelineOrder.order_number}</h3><p>Immutable operational events are shown newest first.</p></div><button className="secondary-button" type="button" onClick={() => setTimelineOrder(null)} disabled={timelineLoading}>Close</button></div>{timelineError && <p className="form-error" role="alert">{timelineError}</p>}{timelineLoading && <p className="form-note">Loading timeline…</p>}{!timelineLoading && !timelineError && timeline.length === 0 && <p className="empty-state">No timeline events recorded.</p>}{!timelineLoading && !timelineError && timeline.length > 0 && <div className="timeline-list">{timeline.map((event) => <article className="timeline-item" key={event.id}><strong>{timelineLabel(event)}</strong><time dateTime={event.event_time}>{new Date(event.event_time).toLocaleString()}</time>{event.parcel_id && <small>Parcel: {event.parcel_id}</small>}{event.notes && <p>{event.notes}</p>}</article>)}</div>}</div>}
      {editing && draft && <div className="order-editor" role="dialog" aria-modal="true" aria-labelledby="edit-order-title"><div className="section-heading"><div><span className="eyebrow">Draft Order</span><h3 id="edit-order-title">Edit {editing.order_number}</h3><p>Changes are saved atomically and are allowed only while the order remains Draft.</p></div><button className="secondary-button" type="button" onClick={closeEditor} disabled={saveLoading}>Cancel</button></div><div className="order-form"><div className="form-row"><label>Customer name<input value={draft.customerName} onChange={(event) => setDraft({ ...draft, customerName: event.target.value })} required /></label><label>Customer phone<input value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} required /></label></div><div className="form-row"><label>City<input value={draft.city} onChange={(event) => setDraft({ ...draft, city: event.target.value })} /></label><label>Total Order Amount (AED)<input type="number" min="0" step="0.01" inputMode="decimal" value={draft.amount} onChange={(event) => setDraft({ ...draft, amount: event.target.value })} required /></label></div><label>Address<input value={draft.address} onChange={(event) => setDraft({ ...draft, address: event.target.value })} /></label><div className="items-heading"><strong>Order items</strong><button className="secondary-button" type="button" onClick={addItem}>+ Add item</button></div>{draft.items.map((item, index) => <div className="item-row" key={index}><input aria-label={`Edit product description ${index + 1}`} value={item.description} onChange={(event) => updateItem(index, 'description', event.target.value)} required /><input aria-label={`Edit quantity ${index + 1}`} type="number" min="1" step="1" value={item.quantity} onChange={(event) => updateItem(index, 'quantity', event.target.value)} required /><button className="remove-button" type="button" onClick={() => removeItem(index)} disabled={draft.items.length === 1}>Remove</button></div>)}<label>Notes<input value={draft.notes} onChange={(event) => setDraft({ ...draft, notes: event.target.value })} /></label><button className="login-button" type="button" onClick={() => void saveDraft()} disabled={saveLoading}>{saveLoading ? 'Saving changes…' : 'Save Draft Changes'}</button>{saveMessage && <p className={saveMessage.startsWith('Order ') ? 'form-success' : 'form-error'} role="status">{saveMessage}</p>}</div></div>}
    </section>
  )
}