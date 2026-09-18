import { useState } from 'react'
import { processRtoBulk, type BulkRtoResult } from '../lib/bulkRto'
import type { ProcessRtoResult } from '../lib/parcelCommands'

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

type Props = {
  accessToken: string
  resolveParcelByBarcode: (accessToken: string, barcode: string) => Promise<Parcel | null>
}

export function BulkRtoWorkspace({ accessToken, resolveParcelByBarcode }: Props) {
  const [input, setInput] = useState('')
  const [items, setItems] = useState<Parcel[]>([])
  const [results, setResults] = useState<BulkRtoResult[]>([])
  const [resolving, setResolving] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState('')

  async function resolveBatch() {
    const barcodes = Array.from(new Set(input.split(/[\n,\s]+/).map((value) => value.trim()).filter(Boolean)))
    if (!barcodes.length || resolving || processing) return
    setResolving(true); setError(''); setResults([])
    try {
      const resolved: Parcel[] = []
      const failures: string[] = []
      for (const barcode of barcodes) {
        try {
          const parcel = await resolveParcelByBarcode(accessToken, barcode)
          if (!parcel) failures.push(`${barcode}: unknown barcode`)
          else resolved.push(parcel)
        } catch (lookupError) {
          failures.push(`${barcode}: ${lookupError instanceof Error ? lookupError.message : 'lookup failed'}`)
        }
      }
      setItems(resolved)
      if (failures.length) setError(failures.join(' · '))
    } finally {
      setResolving(false)
    }
  }

  async function processBatch() {
    const eligible = items.filter((parcel) => ['In Transit', 'NDR'].includes(parcel.state))
    if (!eligible.length || processing) return
    setProcessing(true); setError(''); setResults([])
    try {
      const batchResults = await processRtoBulk(accessToken, eligible.map((parcel) => ({ p_parcel_id: parcel.id, p_note: null })))
      setResults(batchResults)
      const updated = new Map(batchResults.flatMap((entry) => (entry.result ?? []) as ProcessRtoResult[]).map((entry) => [entry.parcel_id, entry]))
      setItems((current) => current.map((parcel) => {
        const result = updated.get(parcel.id)
        return result ? { ...parcel, state: result.state } : parcel
      }))
    } finally {
      setProcessing(false)
    }
  }

  const eligibleCount = items.filter((parcel) => ['In Transit', 'NDR'].includes(parcel.state)).length

  return <section className="card dispatch-scan-workspace" aria-labelledby="bulk-rto-title">
    <div className="section-heading"><div><span className="eyebrow">Lifecycle Gate · T161</span><h2 id="bulk-rto-title">Bulk RTO</h2><p>Resolve a batch of parcel barcodes, then process each eligible parcel through the same atomic RTO command.</p></div><span className="check">Per-parcel results</span></div>
    <label htmlFor="bulk-rto-barcodes">Parcel barcodes</label>
    <textarea id="bulk-rto-barcodes" value={input} onChange={(event) => setInput(event.target.value)} rows={5} placeholder="One barcode per line, or paste a comma/space-separated batch" disabled={resolving || processing} />
    <div className="button-group dispatch-actions"><button className="secondary-button" type="button" onClick={() => void resolveBatch()} disabled={!input.trim() || resolving || processing}>{resolving ? 'Resolving…' : 'Resolve batch'}</button><button className="login-button" type="button" onClick={() => void processBatch()} disabled={!eligibleCount || processing || resolving}>{processing ? 'Processing…' : `Process ${eligibleCount} RTO${eligibleCount === 1 ? '' : 's'}`}</button></div>
    {error && <p className="form-error" role="alert">{error}</p>}
    {items.length > 0 && <div className="orders-table-wrapper"><table><thead><tr><th>Parcel</th><th>State</th><th>Stored shipper</th><th>Tracking</th></tr></thead><tbody>{items.map((parcel) => <tr key={parcel.id}><td>{parcel.parcel_number}</td><td>{parcel.state}</td><td>{parcel.shippers?.name ?? 'Not assigned'}</td><td>{parcel.tracking_id ?? '—'}</td></tr>)}</tbody></table></div>}
    {results.length > 0 && <div className="form-note" role="status">{results.filter((entry) => entry.status === 'success').length} succeeded; {results.filter((entry) => entry.status === 'failure').length} failed. Each parcel was processed independently.</div>}
  </section>
}
