import { useCallback, useEffect, useState } from 'react'
import { listOrders, type OrderListRow } from '../lib/commands'

type Props = { accessToken: string }
type OperationalParcel = { id: string; state: string }
type OperationalCod = { state: string }
type OperationalOrder = OrderListRow & { parcels?: OperationalParcel[]; cod_obligations?: OperationalCod[] }

function StatusPill({ kind, value }: { kind: string; value: string }) {
  return <span className="state-pill" data-status-kind={kind}>{value}</span>
}

export function OperationalStatusIndicators({ accessToken }: Props) {
  const [orders, setOrders] = useState<OperationalOrder[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const refresh = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const result = await listOrders(accessToken, { page: 1, pageSize: 25 })
      setOrders(result.orders as OperationalOrder[])
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to load operational statuses')
    } finally {
      setLoading(false)
    }
  }, [accessToken])

  useEffect(() => {
    const timer = window.setTimeout(() => { void refresh() }, 0)
    return () => window.clearTimeout(timer)
  }, [refresh])

  return <section className="operational-status-indicators" aria-label="Operational status indicators">
    <div className="section-heading"><div><span className="eyebrow">Operational Status</span><strong>Orders at a glance</strong><p>Lifecycle, parcel and COD states are shown as explicit indicators for the current order set.</p></div><button className="secondary-button" type="button" onClick={() => void refresh()} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh statuses'}</button></div>
    {error && <p className="form-error" role="alert">{error}</p>}
    {!error && loading && <p className="form-note">Loading operational statuses…</p>}
    {!error && !loading && orders.length === 0 && <p className="empty-state">No orders available for status indicators.</p>}
    {!error && !loading && orders.length > 0 && <div className="status-indicator-list">{orders.map((order) => <article className="status-indicator-row" key={order.id} aria-label={`Operational status for ${order.order_number}`}><strong>{order.order_number}</strong><div className="status-indicators"><StatusPill kind="lifecycle" value={`Lifecycle: ${order.lifecycle_state}`} />{order.parcels?.length ? order.parcels.map((parcel) => <StatusPill key={parcel.id} kind="parcel" value={`Parcel: ${parcel.state}`} />) : <StatusPill kind="parcel" value="Parcel: Not created" />}{order.cod_obligations?.length ? order.cod_obligations.map((cod, index) => <StatusPill key={`${order.id}-cod-${index}`} kind="cod" value={`COD: ${cod.state}`} />) : <StatusPill kind="cod" value="COD: None" />}</div></article>)}</div>}
  </section>
}
