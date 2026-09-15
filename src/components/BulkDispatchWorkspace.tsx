import { useEffect, useRef, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { dispatchParcelsBulk, type BulkDispatchItem } from '../lib/bulkDispatch'

type Props = { accessToken: string }
type Shipper = { id: string; name: string; active: boolean }
type Parcel = {
  id: string
  parcel_number: string
  barcode: string
  state: string
  tracking_id: string | null
  shipper_id: string | null
  shippers: Shipper | null
}
type QueueItem = BulkDispatchItem & { parcel_number: string; barcode: string; shipper_name: string }

async function resolveParcelByBarcode(accessToken: string, barcode: string): Promise<Parcel | null> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this environment')
  const query = new URLSearchParams({ barcode: `eq.${barcode}`, select: 'id,parcel_number,barcode,state,tracking_id,shipper_id,shippers(id,name,active)', limit: '1' })
  const response = await fetch(`${config.url}/rest/v1/parcels?${query.toString()}`, { headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } })
  const payload = (await response.json().catch(() => null)) as Parcel[] | { message?: string; details?: string } | null
  if (!response.ok) throw new Error((payload as { message?: string; details?: string } | null)?.message ?? (payload as { details?: string } | null)?.details ?? `Parcel lookup failed (${response.status})`)
  return Array.isArray(payload) ? payload[0] ?? null : null
}

export function BulkDispatchWorkspace({ accessToken }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [scan, setScan] = useState('')
  const [queue, setQueue] = useState<QueueItem[]>([])
  const [loading, setLoading] = useState(false)
  const [dispatching, setDispatching] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  useEffect(() => { inputRef.current?.focus() }, [])

  async function handleScan(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const barcode = scan.trim()
    if (!barcode || loading || dispatching) return
    setLoading(true); setError(''); setMessage('')
    try {
      const found = await resolveParcelByBarcode(accessToken, barcode)
      if (!found) throw new Error('Unknown barcode. Scan the parcel barcode again.')
      if (found.state !== 'Prepared') throw new Error(`Parcel ${found.parcel_number} is ${found.state}; only Prepared parcels can be added to a dispatch batch.`)
      if (!found.shipper_id || !found.shippers?.active) throw new Error(`Parcel ${found.parcel_number} does not have an active assigned shipper.`)
      if (!found.tracking_id?.trim()) throw new Error(`Parcel ${found.parcel_number} does not have a tracking ID.`)
      if (queue.some((item) => item.p_parcel_id === found.id)) throw new Error(`Parcel ${found.parcel_number} is already in this dispatch batch.`)
      setQueue((current) => [...current, {
        p_parcel_id: found.id,
        p_tracking_id: found.tracking_id!.trim(),
        p_idempotency_key: crypto.randomUUID(),
        parcel_number: found.parcel_number,
        barcode: found.barcode,
        shipper_name: found.shippers!.name,
      }])
      setScan('')
      setMessage(`Parcel ${found.parcel_number} added to the dispatch batch.`)
    } catch (scanError) {
      setError(scanError instanceof Error ? scanError.message : 'Unable to add parcel to batch')
    } finally {
      setLoading(false); window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  async function handleDispatchBatch() {
    if (!queue.length || dispatching) return
    setDispatching(true); setError(''); setMessage('')
    try {
      await dispatchParcelsBulk(accessToken, queue)
      setQueue([]); setScan('')
      setMessage('Bulk dispatch completed. Each parcel was committed through the individual transactional dispatch command.')
    } catch (dispatchError) {
      setError(dispatchError instanceof Error ? dispatchError.message : 'Bulk dispatch failed')
      setMessage('The batch stopped at the first unconfirmed dispatch. Retry the batch to reuse its existing idempotency keys.')
    } finally {
      setDispatching(false); window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  function removeParcel(parcelId: string) {
    if (dispatching) return
    setQueue((current) => current.filter((item) => item.p_parcel_id !== parcelId))
  }

  function clearQueue() {
    if (dispatching) return
    setQueue([]); setMessage(''); setError(''); setScan(''); inputRef.current?.focus()
  }

  return (
    <section className="card bulk-dispatch-workspace" aria-labelledby="bulk-dispatch-title">
      <div className="section-heading"><div><span className="eyebrow">Dispatch Gate · T143</span><h2 id="bulk-dispatch-title">Bulk Dispatch</h2><p>Scan multiple Prepared parcels, build a batch, then execute the same authoritative dispatch command once per parcel.</p></div><span className="check">Operations / Admin</span></div>
      <form className="dispatch-scan-form" onSubmit={handleScan}><label htmlFor="bulk-dispatch-barcode">Parcel barcode</label><div className="button-group"><input ref={inputRef} id="bulk-dispatch-barcode" value={scan} onChange={(event) => setScan(event.target.value)} placeholder="Scan parcel barcode" autoComplete="off" autoFocus inputMode="text" /><button className="login-button" type="submit" disabled={!scan.trim() || loading || dispatching}>{loading ? 'Adding…' : 'Add to batch'}</button></div><small className="form-note">Only Prepared parcels with an active assigned shipper and existing tracking ID are admitted.</small></form>
      {error && <p className="form-error" role="alert">{error}</p>}{message && <p className="form-note" role="status">{message}</p>}
      {queue.length > 0 ? <><div className="bulk-queue-heading"><strong>Dispatch batch</strong><span className="state-pill">{queue.length} parcel{queue.length === 1 ? '' : 's'}</span></div><div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Parcel</th><th>Tracking ID</th><th>Shipper</th><th /></tr></thead><tbody>{queue.map((item) => <tr key={item.p_parcel_id}><td><strong>{item.parcel_number}</strong><small>{item.barcode}</small></td><td>{item.p_tracking_id}</td><td>{item.shipper_name}</td><td><button className="remove-button" type="button" onClick={() => removeParcel(item.p_parcel_id)} disabled={dispatching}>Remove</button></td></tr>)}</tbody></table></div><div className="button-group bulk-dispatch-actions"><button className="login-button" type="button" onClick={() => void handleDispatchBatch()} disabled={dispatching}>{dispatching ? 'Dispatching batch…' : `Dispatch ${queue.length} parcel${queue.length === 1 ? '' : 's'}`}</button><button className="secondary-button" type="button" onClick={clearQueue} disabled={dispatching}>Clear batch</button></div></> : <p className="empty-state">No parcels in the dispatch batch. Scan a parcel to begin.</p>}
    </section>
  )
}
