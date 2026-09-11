import { useEffect, useState } from 'react'
import { listOrders, type OrderListRow } from '../lib/commands'

type Props = { accessToken: string }

export function OrdersWorkspace({ accessToken }: Props) {
  const [orders, setOrders] = useState<OrderListRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

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

  useEffect(() => { void refresh() }, [accessToken])

  return (
    <section className="card orders-workspace" aria-labelledby="orders-title">
      <div className="section-heading">
        <div><span className="eyebrow">Orders Workspace</span><h2 id="orders-title">Recent Orders</h2><p>Authenticated read-only workspace. State changes remain behind transactional commands.</p></div>
        <button className="secondary-button" type="button" onClick={() => void refresh()} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh'}</button>
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      {!error && loading && <p className="form-note">Loading orders…</p>}
      {!error && !loading && orders.length === 0 && <p className="empty-state">No orders yet. Create the first Draft Order above.</p>}
      {!error && !loading && orders.length > 0 && (
        <div className="orders-table-wrap">
          <table className="orders-table"><thead><tr><th>Order</th><th>Customer</th><th>State</th><th>Amount</th><th>Created</th></tr></thead><tbody>
            {orders.map((order) => <tr key={order.id}><td><strong>{order.order_number}</strong></td><td><span>{order.customers?.name ?? '—'}</span><small>{order.customers?.phone ?? ''}</small></td><td><span className="state-pill">{order.lifecycle_state}</span></td><td>AED {Number(order.original_amount).toFixed(2)}</td><td>{new Date(order.created_at).toLocaleString()}</td></tr>)}
          </tbody></table>
        </div>
      )}
    </section>
  )
}
