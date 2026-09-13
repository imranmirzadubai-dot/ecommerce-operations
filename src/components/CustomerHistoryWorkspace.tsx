import { useState } from 'react'
import { getCustomerHistory, resolveCustomerByPhone, type CustomerHistoryRow } from '../lib/commands'

type Props = { accessToken: string }

export function CustomerHistoryWorkspace({ accessToken }: Props) {
  const [phone, setPhone] = useState('')
  const [customer, setCustomer] = useState<{ customer_id: string; customer_code: string; name: string; phone: string } | null>(null)
  const [history, setHistory] = useState<CustomerHistoryRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [searched, setSearched] = useState(false)

  async function lookup() {
    if (!phone.trim()) return
    setLoading(true)
    setError('')
    setSearched(true)
    try {
      const matches = await resolveCustomerByPhone(accessToken, phone.trim())
      const match = matches[0]
      if (!match) {
        setCustomer(null)
        setHistory([])
        return
      }
      setCustomer({ customer_id: match.customer_id, customer_code: match.customer_code, name: match.name, phone: match.phone })
      setHistory(await getCustomerHistory(accessToken, match.customer_id))
    } catch (lookupError) {
      setCustomer(null)
      setHistory([])
      setError(lookupError instanceof Error ? lookupError.message : 'Customer history lookup failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="card customer-history-workspace" aria-labelledby="customer-history-title">
      <div className="section-heading">
        <div><span className="eyebrow">Customers Workspace</span><h2 id="customer-history-title">Customer History</h2><p>Find a customer by phone and review their stored order history.</p></div>
      </div>
      <div className="form-row customer-history-search">
        <label>Customer phone<input value={phone} onChange={(event) => setPhone(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void lookup() }} placeholder="05xxxxxxxx" /></label>
        <button className="secondary-button" type="button" onClick={() => void lookup()} disabled={loading || !phone.trim()}>{loading ? 'Looking up…' : 'Find history'}</button>
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      {!error && searched && !loading && !customer && <p className="empty-state">No existing customer found for that phone.</p>}
      {customer && !loading && (
        <>
          <div className="customer-history-summary"><strong>{customer.name}</strong><span>{customer.customer_code}</span><span>{customer.phone}</span></div>
          {history.length === 0 ? <p className="empty-state">No orders recorded for this customer.</p> : (
            <div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Order</th><th>Date</th><th>State</th><th>Amount</th></tr></thead><tbody>
              {history.map((order) => <tr key={order.id}><td><strong>{order.order_number}</strong></td><td>{order.order_date}</td><td><span className="state-pill">{order.lifecycle_state}</span></td><td>AED {Number(order.original_amount).toFixed(2)}</td></tr>)}
            </tbody></table></div>
          )}
        </>
      )}
    </section>
  )
}
