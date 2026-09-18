import { useEffect, useRef, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { processRto } from '../lib/parcelCommands'
import { BulkRtoWorkspace } from './BulkRtoWorkspace'

type Props = { accessToken: string }
type Shipper = { id: string; name: string; active: boolean }
type Parcel = { id: string; parcel_number: string; barcode: string; state: string; tracking_id: string | null; shipper_id: string | null; shippers: Shipper | null }

async function resolveParcelByBarcode(accessToken: string, barcode: string): Promise<Parcel | null> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this environment')
  const query = new URLSearchParams({ barcode: `eq.${barcode}`, select: 'id,parcel_number,barcode,state,tracking_id,shipper_id,shippers(id,name,active)', limit: '1' })
  const response = await fetch(`${config.url}/rest/v1/parcels?${query.toString()}`, { headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } })
  const payload = (await response.json().catch(() => null)) as Parcel[] | { message?: string; details?: string } | null
  if (!response.ok) throw new Error((payload as { message?: string; details?: string } | null)?.message ?? (payload as { details?: string } | null)?.details ?? `Parcel lookup failed (${response.status})`)
  return Array.isArray(payload) ? payload[0] ?? null : null
}

export function RtoScanWorkspace({ accessToken }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [scan, setScan] = useState('')
  const [parcel, setParcel] = useState<Parcel | null>(null)
  const [rtoIdempotencyKey, setRtoIdempotencyKey] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  useEffect(() => { inputRef.current?.focus() }, [])

  async function handleScan(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const barcode = scan.trim()
    if (!barcode || loading || processing) return
    setLoading(true); setError(''); setMessage(''); setParcel(null); setRtoIdempotencyKey(null)
    try {
      const found = await resolveParcelByBarcode(accessToken, barcode)
      if (!found) throw new Error('Unknown barcode. Scan the parcel barcode again.')
      setParcel(found); setRtoIdempotencyKey(`rto:${found.id}`)
      if (found.state === 'In Transit' || found.state === 'NDR') setMessage(`Parcel resolved. Stored shipper: ${found.shippers?.name ?? 'not assigned'}.`)
      else setMessage(`Parcel resolved in ${found.state} state. RTO is only available from In Transit or NDR.`)
    } catch (lookupError) { setError(lookupError instanceof Error ? lookupError.message : 'Unable to resolve barcode') }
    finally { setLoading(false); window.setTimeout(() => inputRef.current?.focus(), 0) }
  }

  async function handleRto() {
    if (!parcel || !rtoIdempotencyKey || processing || !['In Transit', 'NDR'].includes(parcel.state)) return
    setProcessing(true); setError(''); setMessage('')
    try {
      const result = await processRto(accessToken, { p_parcel_id: parcel.id, p_note: null, p_idempotency_key: rtoIdempotencyKey })
      const processed = result[0]
      if (!processed) throw new Error('RTO completed without returning the parcel')
      setParcel({ ...parcel, state: processed.state }); setScan('')
      setMessage(`Parcel ${processed.parcel_number} processed as RTO. Stored shipper: ${processed.shipper_name ?? 'not assigned'}.`)
    } catch (rtoError) { setError(rtoError instanceof Error ? rtoError.message : 'RTO processing failed') }
    finally { setProcessing(false); window.setTimeout(() => inputRef.current?.focus(), 0) }
  }

  const canProcess = parcel !== null && rtoIdempotencyKey !== null && ['In Transit', 'NDR'].includes(parcel.state)
  return <>
    <section className="card dispatch-scan-workspace" aria-labelledby="rto-scan-title">
      <div className="section-heading"><div><span className="eyebrow">Lifecycle Gate · T161/T162</span><h2 id="rto-scan-title">Scan-first RTO</h2><p>Scan the parcel barcode. The stored shipper is resolved automatically; the operator does not select a historical shipper.</p></div><span className="check">Operations / Admin</span></div>
      <form className="dispatch-scan-form" onSubmit={handleScan}><label htmlFor="rto-barcode">Parcel barcode</label><div className="button-group"><input ref={inputRef} id="rto-barcode" value={scan} onChange={(event) => setScan(event.target.value)} placeholder="Scan parcel barcode" autoComplete="off" autoFocus inputMode="text" /><button className="login-button" type="submit" disabled={!scan.trim() || loading || processing}>{loading ? 'Resolving…' : 'Resolve parcel'}</button></div><small className="form-note">Only In Transit and NDR parcels are eligible for RTO.</small></form>
      {error && <p className="form-error" role="alert">{error}</p>}{message && <p className={parcel?.state === 'RTO' ? 'form-success' : 'form-note'} role="status">{message}</p>}
      {parcel && <div className="dispatch-parcel-panel"><div><span className="eyebrow">Parcel</span><strong>{parcel.parcel_number}</strong><small>{parcel.barcode}</small></div><div><span className="eyebrow">State</span><strong>{parcel.state}</strong></div><div><span className="eyebrow">Stored shipper</span><strong>{parcel.shippers?.name ?? 'Not assigned'}</strong><small>{parcel.shippers?.active ? 'Active' : 'Stored historical assignment'}</small></div><div><span className="eyebrow">Tracking ID</span><strong>{parcel.tracking_id ?? '—'}</strong></div></div>}
      {parcel && <div className="button-group dispatch-actions"><button className="login-button" type="button" onClick={() => void handleRto()} disabled={!canProcess || processing}>{processing ? 'Processing RTO…' : 'Process RTO'}</button><button className="secondary-button" type="button" onClick={() => { setScan(''); setParcel(null); setRtoIdempotencyKey(null); setMessage(''); setError(''); inputRef.current?.focus() }} disabled={loading || processing}>Scan another parcel</button></div>}
    </section>
    <BulkRtoWorkspace accessToken={accessToken} resolveParcelByBarcode={resolveParcelByBarcode} />
  </>
}
