import { useEffect, useRef, useState } from 'react'
import { getAuthConfig } from '../lib/auth'
import { dispatchParcel } from '../lib/parcelCommands'
import { BulkDispatchWorkspace } from './BulkDispatchWorkspace'
import '../styles/dispatch-responsive.css'
import '../styles/mobile-acceptance.css'

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
type BarcodeResult = { rawValue: string }
type BarcodeDetectorInstance = { detect(source: ImageBitmapSource): Promise<BarcodeResult[]> }
type BarcodeDetectorConstructor = new (options?: { formats?: string[] }) => BarcodeDetectorInstance

type BarcodeScannerProps = { onDetected: (value: string) => void; onClose: () => void }

async function resolveParcelByBarcode(accessToken: string, barcode: string): Promise<Parcel | null> {
  const config = getAuthConfig()
  if (!config) throw new Error('Supabase is not configured for this environment')
  const query = new URLSearchParams({ barcode: `eq.${barcode}`, select: 'id,parcel_number,barcode,state,tracking_id,shipper_id,shippers(id,name,active)', limit: '1' })
  const response = await fetch(`${config.url}/rest/v1/parcels?${query.toString()}`, { headers: { apikey: config.publishableKey, Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } })
  const payload = (await response.json().catch(() => null)) as Parcel[] | { message?: string; details?: string } | null
  if (!response.ok) throw new Error((payload as { message?: string; details?: string } | null)?.message ?? (payload as { details?: string } | null)?.details ?? `Parcel lookup failed (${response.status})`)
  return Array.isArray(payload) ? payload[0] ?? null : null
}

function newIdempotencyKey() { return crypto.randomUUID() }

function BarcodeScanner({ onDetected, onClose }: BarcodeScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<number | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    const stop = () => {
      if (timerRef.current !== null) window.clearTimeout(timerRef.current)
      timerRef.current = null
      streamRef.current?.getTracks().forEach((track) => track.stop())
      streamRef.current = null
      if (videoRef.current) videoRef.current.srcObject = null
    }

    const start = async () => {
      try {
        if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) throw new Error('Camera access requires a secure HTTPS page and a browser with camera support.')
        const Detector = (window as Window & { BarcodeDetector?: BarcodeDetectorConstructor }).BarcodeDetector
        if (!Detector) throw new Error('Live barcode scanning is not supported by this browser. Use the manual parcel barcode field instead.')
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false })
        if (!active) { stream.getTracks().forEach((track) => track.stop()); return }
        streamRef.current = stream
        const video = videoRef.current
        if (!video) throw new Error('Camera preview could not be initialized.')
        video.srcObject = stream
        await video.play()
        const detector = new Detector({ formats: ['code_128', 'code_39', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'itf', 'codabar'] })
        const scanFrame = async () => {
          if (!active || !videoRef.current) return
          try {
            const results = await detector.detect(videoRef.current)
            const value = results.find((result) => result.rawValue.trim())?.rawValue.trim()
            if (value) { onDetected(value); return }
          } catch { /* Keep scanning; transient frame decode errors are expected. */ }
          if (active) timerRef.current = window.setTimeout(() => void scanFrame(), 140)
        }
        void scanFrame()
      } catch (scannerError) {
        if (active) setError(scannerError instanceof Error ? scannerError.message : 'Unable to start the camera scanner.')
      }
    }

    void start()
    return () => { active = false; stop() }
  }, [onDetected])

  return <div className="mobile-barcode-scanner" role="dialog" aria-modal="true" aria-labelledby="barcode-scanner-title">
    <div className="mobile-barcode-scanner__header"><strong id="barcode-scanner-title">Scan Parcel Barcode</strong><button className="mobile-barcode-scanner__close" type="button" onClick={onClose}>Close</button></div>
    <div className="mobile-barcode-scanner__viewport">
      <video ref={videoRef} className="mobile-barcode-scanner__video" autoPlay muted playsInline aria-label="Parcel barcode camera preview" />
      <div className="mobile-barcode-scanner__frame" aria-hidden="true" />
      {!error && <div className="mobile-barcode-scanner__hint">Point the rear camera at the parcel barcode. Scanning is automatic.</div>}
    </div>
    {error && <p className="mobile-barcode-scanner__error" role="alert">{error}</p>}
    <div className="mobile-barcode-scanner__footer"><button type="button" onClick={onClose}>Enter barcode manually</button></div>
  </div>
}

export function DispatchScanWorkspace({ accessToken }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const dispatchAttemptKeys = useRef(new Map<string, string>())
  const [scan, setScan] = useState('')
  const [parcel, setParcel] = useState<Parcel | null>(null)
  const [tracking, setTracking] = useState('')
  const [loading, setLoading] = useState(false)
  const [dispatching, setDispatching] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [scannerOpen, setScannerOpen] = useState(false)

  useEffect(() => { inputRef.current?.focus() }, [])

  const handleCameraDetected = (barcode: string) => {
    setScan(barcode)
    setScannerOpen(false)
    window.setTimeout(() => inputRef.current?.focus(), 0)
    void resolveScannedBarcode(barcode)
  }

  async function resolveScannedBarcode(rawBarcode: string) {
    const barcode = rawBarcode.trim()
    if (!barcode || loading || dispatching) return
    setLoading(true); setError(''); setMessage(''); setParcel(null); setTracking('')
    try {
      const found = await resolveParcelByBarcode(accessToken, barcode)
      if (!found) throw new Error('Unknown barcode. Scan the parcel barcode again.')
      setParcel(found)
      if (found.tracking_id) setTracking(found.tracking_id)
      if (found.state === 'Dispatched') setMessage(`Duplicate scan: parcel ${found.parcel_number} is already Dispatched. No duplicate dispatch was created.`)
      else if (found.state === 'Prepared') setMessage('Parcel resolved. Confirm the tracking ID and dispatch.')
      else setMessage(`Parcel resolved in ${found.state} state.`)
    } catch (lookupError) {
      setError(lookupError instanceof Error ? lookupError.message : 'Unable to resolve barcode')
    } finally {
      setLoading(false); window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  async function handleScan(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    await resolveScannedBarcode(scan)
  }

  async function handleDispatch() {
    if (!parcel || dispatching || parcel.state !== 'Prepared') return
    const trackingId = tracking.trim()
    if (!trackingId) return
    const attemptKey = `${parcel.id}:${trackingId}`
    const idempotencyKey = dispatchAttemptKeys.current.get(attemptKey) ?? newIdempotencyKey()
    dispatchAttemptKeys.current.set(attemptKey, idempotencyKey)
    setDispatching(true); setError(''); setMessage('')
    try {
      const result = await dispatchParcel(accessToken, { p_parcel_id: parcel.id, p_tracking_id: trackingId, p_idempotency_key: idempotencyKey })
      const dispatched = result[0]
      if (!dispatched) throw new Error('Dispatch completed without returning the parcel')
      dispatchAttemptKeys.current.delete(attemptKey)
      setParcel({ ...parcel, state: dispatched.state, tracking_id: dispatched.tracking_id }); setTracking(dispatched.tracking_id); setScan('')
      setMessage(`Parcel ${dispatched.parcel_number} dispatched to ${dispatched.shipper_name}.`)
    } catch (dispatchError) {
      setError(dispatchError instanceof Error ? dispatchError.message : 'Dispatch failed')
      setMessage('The dispatch was not confirmed. Retrying this parcel will reuse the same idempotency key.')
    } finally {
      setDispatching(false); window.setTimeout(() => inputRef.current?.focus(), 0)
    }
  }

  function resetScan() {
    if (loading || dispatching) return
    setScan(''); setParcel(null); setTracking(''); setMessage(''); setError(''); inputRef.current?.focus()
  }

  const canDispatch = parcel?.state === 'Prepared' && Boolean(parcel.shipper_id) && Boolean(parcel.shippers?.active) && tracking.trim().length > 0

  return <>
    <section className="card dispatch-scan-workspace" aria-labelledby="dispatch-scan-title">
      <div className="section-heading"><div><span className="eyebrow">Dispatch Gate · T142</span><h2 id="dispatch-scan-title">Scan-first Dispatch</h2><p>Scan the parcel barcode, verify the assigned shipper and tracking ID, then commit the individual dispatch.</p></div><span className="check">Operations / Admin</span></div>
      <form className="dispatch-scan-form" onSubmit={handleScan}><label htmlFor="dispatch-barcode">Parcel barcode</label><div className="dispatch-scan-entry"><input ref={inputRef} id="dispatch-barcode" value={scan} onChange={(event) => setScan(event.target.value)} placeholder="Enter barcode manually" autoComplete="off" autoFocus inputMode="text" aria-describedby="dispatch-scan-help" /><button className="secondary-button" type="button" onClick={() => setScannerOpen(true)} disabled={loading || dispatching}>Scan with camera</button></div><button className="login-button" type="submit" disabled={!scan.trim() || loading || dispatching}>{loading ? 'Resolving…' : 'Resolve parcel'}</button><small id="dispatch-scan-help" className="form-note">The barcode is the immutable parcel number. Scanner input should submit with Enter.</small></form>
      {error && <p className="form-error" role="alert">{error}</p>}{message && <p className={parcel?.state === 'Dispatched' ? 'form-success' : 'form-note'} role="status">{message}</p>}
      {parcel && <div className="dispatch-parcel-panel"><div><span className="eyebrow">Parcel</span><strong>{parcel.parcel_number}</strong><small>{parcel.barcode}</small></div><div><span className="eyebrow">State</span><strong>{parcel.state}</strong></div><div><span className="eyebrow">Assigned shipper</span><strong>{parcel.shippers?.name ?? 'Not assigned'}</strong><small>{parcel.shippers?.active ? 'Active' : 'Inactive / unavailable'}</small></div><label><span className="eyebrow">Tracking ID</span><input value={tracking} onChange={(event) => setTracking(event.target.value)} placeholder="Enter tracking ID" disabled={dispatching || parcel.state !== 'Prepared'} /></label></div>}
      {parcel && <div className="button-group dispatch-actions"><button className="login-button" type="button" onClick={() => void handleDispatch()} disabled={!canDispatch || dispatching}>{dispatching ? 'Dispatching…' : 'Dispatch parcel'}</button><button className="secondary-button" type="button" onClick={resetScan} disabled={loading || dispatching}>Scan another parcel</button></div>}
    </section>
    <BulkDispatchWorkspace accessToken={accessToken} />
    {scannerOpen && <BarcodeScanner onDetected={handleCameraDetected} onClose={() => setScannerOpen(false)} />}
  </>
}
