import { useEffect, useRef, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { recordDeliveryOutcome, retryNdrParcel, type RecordDeliveryOutcomeResult, type RetryNdrParcelResult } from '../lib/parcelCommands'

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

async function resolveParcelByBarcode(accessToken: string, barcode: string): Promise<Parcel | null> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this environment')
  const query = new URLSearchParams({
    barcode: `eq.${barcode}`,
    select: 'id,parcel_number,barcode,state,tracking_id,shipper_id,shippers(id,name,active)',
    limit: '1',
  })
  const response = await fetch(`${config.url}/rest/v1/parcels?${query.toString()}`, {
    headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  })
  const payload = (await response.json().catch(() => null)) as Parcel[] | { message?: string; details?: string } | null
  if (!response.ok) {
    const detail = payload as { message?: string; details?: string } | null
    throw new Error(detail?.message ?? detail?.details ?? `Parcel lookup failed (${response.status})`)
  }
  return Array.isArray(payload) ? payload[0] ?? null : null
}

export function DeliveryOutcomeWorkspace({ accessToken }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [scan, setScan] = useState('')
  const [parcel, setParcel] = useState<Parcel | null>(null)
  const [outcome, setOutcome] = useState<'Delivered' | 'NDR' | 'Lost' | 'Damaged'>('Delivered')
  const [note, setNote] = useState('')
  const [loading, setLoading] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  useEffect(() => { inputRef.current?.focus() }, [])

  async function handleScan(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const barcode = scan.trim()
    if (!barcode || loading || processing) return
    setLoading(true); setError(''); setMessage(''); setParcel(null)
    try {
      const found = await resolveParcelByBarcode(accessToken, barcode)
      if (!found) throw new Error('Unknown barcode. Scan the parcel barcode again.')
      setParcel(found)
      if (found.state === 'In Transit') {
        setMessage(`Parcel resolved. Ready to record a delivery outcome.`)
      } else if (found.state === 'NDR') {
        setOutcome('Delivered')
        setMessage('NDR parcel resolved. It may be completed as Delivered, or retried for another delivery attempt.')
      } else {
        setMessage(`Parcel resolved in ${found.state} state. No further delivery outcome is available.`)
      }
    } catch (lookupError) {
      setError(lookupError instanceof Error ? lookupError.message : 'Unable to resolve barcode')
    } finally {
      setLoading(false)
      window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  async function handleOutcome() {
    if (!parcel || processing) return
    if (!['In Transit', 'NDR'].includes(parcel.state)) return
    if (parcel.state === 'NDR' && outcome !== 'Delivered') return
    setProcessing(true); setError(''); setMessage('')
    try {
      const result = await recordDeliveryOutcome(accessToken, {
        p_parcel_id: parcel.id,
        p_outcome: outcome,
        p_note: note.trim() || null,
        p_idempotency_key: crypto.randomUUID(),
      })
      const recorded = result[0] as RecordDeliveryOutcomeResult | undefined
      if (!recorded) throw new Error('Delivery outcome completed without returning the parcel')
      setParcel({ ...parcel, state: recorded.state })
      setScan('')
      setNote('')
      setMessage(`Parcel ${recorded.parcel_number} recorded as ${recorded.state}.`)
    } catch (outcomeError) {
      setError(outcomeError instanceof Error ? outcomeError.message : 'Delivery outcome failed')
    } finally {
      setProcessing(false)
      window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  async function handleRetry() {
    if (!parcel || processing || parcel.state !== 'NDR') return
    setProcessing(true); setError(''); setMessage('')
    try {
      const result = await retryNdrParcel(accessToken, {
        p_parcel_id: parcel.id,
        p_note: note.trim() || null,
        p_idempotency_key: crypto.randomUUID(),
      })
      const retried = result[0] as RetryNdrParcelResult | undefined
      if (!retried) throw new Error('NDR retry completed without returning the parcel')
      setParcel({ ...parcel, state: retried.state })
      setScan('')
      setNote('')
      setMessage(`Parcel ${retried.parcel_number} retried and returned to ${retried.state}.`)
    } catch (retryError) {
      setError(retryError instanceof Error ? retryError.message : 'NDR retry failed')
    } finally {
      setProcessing(false)
      window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  function resetScan() {
    if (loading || processing) return
    setScan(''); setParcel(null); setOutcome('Delivered'); setNote(''); setMessage(''); setError('')
    inputRef.current?.focus()
  }

  const canOutcome = Boolean(parcel) && !processing && (parcel?.state === 'In Transit' || parcel?.state === 'NDR') && !(parcel?.state === 'NDR' && outcome !== 'Delivered')
  const terminal = parcel !== null && ['Delivered', 'RTO', 'Lost', 'Damaged', 'Cancelled'].includes(parcel.state)

  return <section className="card dispatch-scan-workspace" aria-labelledby="delivery-outcome-title">
    <div className="section-heading">
      <div>
        <span className="eyebrow">Delivery Gate · T234</span>
        <h2 id="delivery-outcome-title">Delivery / NDR outcomes</h2>
        <p>Scan a parcel, record an authoritative delivery outcome, or retry an NDR parcel for another delivery attempt.</p>
      </div>
      <span className="check">Operations / Admin</span>
    </div>

    <form className="dispatch-scan-form" onSubmit={handleScan}>
      <label htmlFor="delivery-outcome-barcode">Parcel barcode</label>
      <div className="button-group">
        <input ref={inputRef} id="delivery-outcome-barcode" value={scan} onChange={(event) => setScan(event.target.value)} placeholder="Scan parcel barcode" autoComplete="off" autoFocus inputMode="text" />
        <button className="login-button" type="submit" disabled={!scan.trim() || loading || processing}>{loading ? 'Resolving…' : 'Resolve parcel'}</button>
      </div>
      <small className="form-note">In Transit parcels can be Delivered, marked NDR, Lost or Damaged. NDR can be completed as Delivered or retried.</small>
    </form>

    {error && <p className="form-error" role="alert">{error}</p>}
    {message && <p className={terminal ? 'form-success' : 'form-note'} role="status">{message}</p>}

    {parcel && <div className="dispatch-parcel-panel">
      <div><span className="eyebrow">Parcel</span><strong>{parcel.parcel_number}</strong><small>{parcel.barcode}</small></div>
      <div><span className="eyebrow">State</span><strong>{parcel.state}</strong></div>
      <div><span className="eyebrow">Shipper</span><strong>{parcel.shippers?.name ?? 'Not assigned'}</strong><small>{parcel.shippers?.active ? 'Active' : parcel.shipper_id ? 'Stored historical assignment' : 'Not assigned'}</small></div>
      <div><span className="eyebrow">Tracking ID</span><strong>{parcel.tracking_id ?? '—'}</strong></div>
    </div>}

    {parcel && !terminal && <div className="order-form">
      {parcel.state === 'In Transit' && <label>
        Delivery outcome
        <select value={outcome} onChange={(event) => setOutcome(event.target.value as typeof outcome)} disabled={processing}>
          <option value="Delivered">Delivered</option>
          <option value="NDR">NDR</option>
          <option value="Lost">Lost</option>
          <option value="Damaged">Damaged</option>
        </select>
      </label>}
      {parcel.state === 'NDR' && <p className="form-note">NDR follow-up: choose Delivered or use Retry NDR to return the parcel to In Transit.</p>}
      <label>
        Note
        <input value={note} onChange={(event) => setNote(event.target.value)} placeholder="Optional delivery/NDR note" disabled={processing} />
      </label>
      <div className="button-group">
        <button className="login-button" type="button" onClick={() => void handleOutcome()} disabled={!canOutcome || processing}>{processing ? 'Recording…' : 'Record outcome'}</button>
        {parcel.state === 'NDR' && <button className="secondary-button" type="button" onClick={() => void handleRetry()} disabled={processing}>{processing ? 'Processing…' : 'Retry NDR'}</button>}
        <button className="secondary-button" type="button" onClick={resetScan} disabled={loading || processing}>Scan another parcel</button>
      </div>
    </div>}

    {parcel && terminal && <div className="button-group dispatch-actions">
      <button className="secondary-button" type="button" onClick={resetScan} disabled={loading || processing}>Scan another parcel</button>
    </div>}
  </section>
}
