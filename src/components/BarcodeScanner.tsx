import { useEffect, useRef, useState } from 'react'

type BarcodeResult = { rawValue: string }
type BarcodeDetectorInstance = { detect(source: ImageBitmapSource): Promise<BarcodeResult[]> }
type BarcodeDetectorConstructor = new (options?: { formats?: string[] }) => BarcodeDetectorInstance

type Props = {
  title?: string
  onDetected: (value: string) => void
  onClose: () => void
}

export function BarcodeScanner({ title = 'Scan Parcel Barcode', onDetected, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<number | null>(null)
  const activeRef = useRef(true)
  const startingRef = useRef(false)
  const onDetectedRef = useRef(onDetected)
  const [error, setError] = useState('')
  const [autoScanAvailable, setAutoScanAvailable] = useState(false)

  useEffect(() => {
    onDetectedRef.current = onDetected
  }, [onDetected])

  useEffect(() => {
    activeRef.current = true

    const stop = () => {
      if (timerRef.current !== null) window.clearTimeout(timerRef.current)
      timerRef.current = null
      streamRef.current?.getTracks().forEach((track) => track.stop())
      streamRef.current = null
      const video = videoRef.current
      if (video) {
        video.pause()
        video.srcObject = null
      }
    }

    const waitForVideo = (video: HTMLVideoElement) => new Promise<void>((resolve, reject) => {
      if (video.readyState >= HTMLMediaElement.HAVE_METADATA) {
        resolve()
        return
      }

      let settled = false
      const cleanup = () => {
        window.clearTimeout(timeout)
        video.removeEventListener('loadedmetadata', handleReady)
        video.removeEventListener('loadeddata', handleReady)
        video.removeEventListener('canplay', handleReady)
      }
      const handleReady = () => {
        if (settled) return
        settled = true
        cleanup()
        resolve()
      }
      const timeout = window.setTimeout(async () => {
        if (settled) return
        try {
          await video.play()
          if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
            settled = true
            cleanup()
            resolve()
            return
          }
        } catch {
          // Fall through to the user-visible initialization error.
        }
        settled = true
        cleanup()
        reject(new Error('Camera preview did not initialize.'))
      }, 8000)

      video.addEventListener('loadedmetadata', handleReady)
      video.addEventListener('loadeddata', handleReady)
      video.addEventListener('canplay', handleReady)
    })

    const start = async () => {
      if (!activeRef.current || startingRef.current || streamRef.current) return
      startingRef.current = true
      setError('')
      try {
        if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
          throw new Error('Camera access requires a secure HTTPS page and a browser with camera support.')
        }

        const Detector = (window as Window & { BarcodeDetector?: BarcodeDetectorConstructor }).BarcodeDetector
        let detector: BarcodeDetectorInstance | null = null
        if (Detector) {
          try {
            detector = new Detector({ formats: ['code_128', 'code_39', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'itf', 'codabar'] })
          } catch {
            detector = null
          }
        }
        setAutoScanAvailable(Boolean(detector))

        const video = videoRef.current
        if (!video) throw new Error('Camera preview could not be initialized.')
        video.muted = true
        video.playsInline = true
        video.autoplay = true

        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false,
        })
        if (!activeRef.current) {
          stream.getTracks().forEach((track) => track.stop())
          return
        }

        // Install readiness listeners before attaching the stream so fast mobile
        // browsers cannot fire loadedmetadata before waitForVideo starts listening.
        const videoReady = waitForVideo(video)
        streamRef.current = stream
        video.srcObject = stream
        await videoReady
        await video.play()

        if (!activeRef.current) return

        const scanFrame = async () => {
          if (!activeRef.current || !detector || !videoRef.current || videoRef.current.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return
          try {
            const results = await detector.detect(videoRef.current)
            const value = results.find((result) => result.rawValue.trim())?.rawValue.trim()
            if (value) {
              onDetectedRef.current(value)
              return
            }
          } catch {
            // Transient frame decode errors are expected; keep the camera active.
          }
          if (activeRef.current && streamRef.current) timerRef.current = window.setTimeout(() => void scanFrame(), 140)
        }

        void scanFrame()

        const handleTrackEnded = () => {
          if (activeRef.current) {
            stop()
            void start()
          }
        }
        stream.getVideoTracks().forEach((track) => track.addEventListener('ended', handleTrackEnded, { once: true }))
      } catch (scannerError) {
        if (activeRef.current) setError(scannerError instanceof Error ? scannerError.message : 'Unable to start the camera scanner.')
      } finally {
        startingRef.current = false
      }
    }

    const handleVisibility = () => {
      if (!activeRef.current) return
      if (document.hidden) stop()
      else void start()
    }
    document.addEventListener('visibilitychange', handleVisibility)
    void start()

    return () => {
      activeRef.current = false
      document.removeEventListener('visibilitychange', handleVisibility)
      stop()
    }
  }, [])

  return <div className="mobile-barcode-scanner" role="dialog" aria-modal="true" aria-labelledby="barcode-scanner-title">
    <div className="mobile-barcode-scanner__header"><strong id="barcode-scanner-title">{title}</strong><button className="mobile-barcode-scanner__close" type="button" onClick={onClose}>Close</button></div>
    <div className="mobile-barcode-scanner__viewport">
      <video ref={videoRef} className="mobile-barcode-scanner__video" autoPlay muted playsInline aria-label="Parcel barcode camera preview" />
      <div className="mobile-barcode-scanner__frame" aria-hidden="true" />
      {!error && <div className="mobile-barcode-scanner__hint">{autoScanAvailable ? 'Point the rear camera at the parcel barcode. Scanning is automatic.' : 'Camera is active. Automatic barcode scanning is not supported by this browser; use the manual barcode field below.'}</div>}
    </div>
    {error && <p className="mobile-barcode-scanner__error" role="alert">{error}</p>}
    <div className="mobile-barcode-scanner__footer"><button type="button" onClick={onClose}>Enter barcode manually</button></div>
  </div>
}
