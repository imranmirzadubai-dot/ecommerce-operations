import { useEffect, useRef, useState } from 'react'

type BarcodeBoundingBox = {
  x: number
  y: number
  width: number
  height: number
}

type BarcodeResult = {
  rawValue: string
  boundingBox?: BarcodeBoundingBox
}

type BarcodeDetectorInstance = { detect(source: ImageBitmapSource): Promise<BarcodeResult[]> }
type BarcodeDetectorConstructor = new (options?: { formats?: string[] }) => BarcodeDetectorInstance

type Props = {
  title?: string
  onDetected: (value: string) => void
  onClose: () => void
}

type Candidate = {
  value: string
  centerX: number
  centerY: number
  width: number
  height: number
  count: number
}

const SCAN_ZONE_COVERAGE = 0.8
const REQUIRED_STABLE_DETECTIONS = 3
const MAX_CENTER_MOVEMENT_RATIO = 0.35
const MAX_SIZE_CHANGE_RATIO = 0.6

function getIntersectionArea(first: BarcodeBoundingBox, second: BarcodeBoundingBox) {
  const left = Math.max(first.x, second.x)
  const top = Math.max(first.y, second.y)
  const right = Math.min(first.x + first.width, second.x + second.width)
  const bottom = Math.min(first.y + first.height, second.y + second.height)
  if (right <= left || bottom <= top) return 0
  return (right - left) * (bottom - top)
}

function getScanZoneInVideoCoordinates(video: HTMLVideoElement, frame: HTMLDivElement): BarcodeBoundingBox | null {
  if (!video.videoWidth || !video.videoHeight) return null

  const videoRect = video.getBoundingClientRect()
  const frameRect = frame.getBoundingClientRect()
  if (!videoRect.width || !videoRect.height) return null

  // The video uses object-fit: cover. Convert the visible scan frame from CSS
  // coordinates into the video's intrinsic pixel coordinates so BarcodeDetector's
  // boundingBox can be compared against it accurately.
  const scale = Math.max(videoRect.width / video.videoWidth, videoRect.height / video.videoHeight)
  const renderedWidth = video.videoWidth * scale
  const renderedHeight = video.videoHeight * scale
  const offsetX = (videoRect.width - renderedWidth) / 2
  const offsetY = (videoRect.height - renderedHeight) / 2

  return {
    x: (frameRect.left - videoRect.left - offsetX) / scale,
    y: (frameRect.top - videoRect.top - offsetY) / scale,
    width: frameRect.width / scale,
    height: frameRect.height / scale,
  }
}

function isBarcodeInsideScanZone(barcode: BarcodeBoundingBox, zone: BarcodeBoundingBox) {
  if (barcode.width <= 0 || barcode.height <= 0) return false
  const barcodeArea = barcode.width * barcode.height
  return getIntersectionArea(barcode, zone) / barcodeArea >= SCAN_ZONE_COVERAGE
}

function isStableWithPrevious(previous: Candidate | null, barcode: BarcodeBoundingBox) {
  if (!previous) return true

  const centerX = barcode.x + barcode.width / 2
  const centerY = barcode.y + barcode.height / 2
  const previousDiagonal = Math.hypot(previous.width, previous.height)
  const movement = Math.hypot(centerX - previous.centerX, centerY - previous.centerY)
  const widthChange = Math.abs(barcode.width - previous.width) / Math.max(previous.width, 1)
  const heightChange = Math.abs(barcode.height - previous.height) / Math.max(previous.height, 1)

  return movement <= previousDiagonal * MAX_CENTER_MOVEMENT_RATIO
    && widthChange <= MAX_SIZE_CHANGE_RATIO
    && heightChange <= MAX_SIZE_CHANGE_RATIO
}

export function BarcodeScanner({ title = 'Scan Parcel Barcode', onDetected, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const frameRef = useRef<HTMLDivElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<number | null>(null)
  const activeRef = useRef(true)
  const startingRef = useRef(false)
  const acceptedRef = useRef(false)
  const candidateRef = useRef<Candidate | null>(null)
  const onDetectedRef = useRef(onDetected)
  const [error, setError] = useState('')
  const [autoScanAvailable, setAutoScanAvailable] = useState(false)
  const [scanStatus, setScanStatus] = useState('Align the barcode inside the box.')

  useEffect(() => {
    onDetectedRef.current = onDetected
  }, [onDetected])

  useEffect(() => {
    activeRef.current = true

    const resetCandidate = (status = 'Align the barcode inside the box.') => {
      candidateRef.current = null
      setScanStatus(status)
    }

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
      resetCandidate()
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
      acceptedRef.current = false
      resetCandidate()
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
        const frame = frameRef.current
        if (!video || !frame) throw new Error('Camera preview could not be initialized.')
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
          if (!activeRef.current || acceptedRef.current || !detector || !videoRef.current || videoRef.current.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return

          try {
            const results = await detector.detect(videoRef.current)
            const zone = frameRef.current ? getScanZoneInVideoCoordinates(videoRef.current, frameRef.current) : null
            const result = results
              .filter((item) => item.rawValue.trim() && item.boundingBox)
              .map((item) => ({ value: item.rawValue.trim(), boundingBox: item.boundingBox as BarcodeBoundingBox }))
              .find((item) => zone && isBarcodeInsideScanZone(item.boundingBox, zone))

            if (!result) {
              resetCandidate('Align the barcode fully inside the box.')
            } else {
              const { value, boundingBox } = result
              const previous = candidateRef.current
              const stable = previous?.value === value && isStableWithPrevious(previous, boundingBox)

              if (stable && previous) {
                const nextCount = previous.count + 1
                candidateRef.current = {
                  ...previous,
                  centerX: boundingBox.x + boundingBox.width / 2,
                  centerY: boundingBox.y + boundingBox.height / 2,
                  width: boundingBox.width,
                  height: boundingBox.height,
                  count: nextCount,
                }
                if (nextCount >= REQUIRED_STABLE_DETECTIONS) {
                  acceptedRef.current = true
                  setScanStatus('Barcode verified.')
                  onDetectedRef.current(value)
                  return
                }
                setScanStatus(`Hold steady… verifying barcode (${nextCount}/${REQUIRED_STABLE_DETECTIONS})`)
              } else {
                candidateRef.current = {
                  value,
                  centerX: boundingBox.x + boundingBox.width / 2,
                  centerY: boundingBox.y + boundingBox.height / 2,
                  width: boundingBox.width,
                  height: boundingBox.height,
                  count: 1,
                }
                setScanStatus(`Hold steady… verifying barcode (1/${REQUIRED_STABLE_DETECTIONS})`)
              }
            }
          } catch {
            // Transient frame decode errors are expected; keep the camera active.
          }

          if (activeRef.current && streamRef.current && !acceptedRef.current) {
            timerRef.current = window.setTimeout(() => void scanFrame(), 140)
          }
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
      <div ref={frameRef} className="mobile-barcode-scanner__frame" aria-hidden="true" />
      {!error && <div className="mobile-barcode-scanner__hint">{autoScanAvailable ? scanStatus : 'Camera is active. Automatic barcode scanning is not supported by this browser; use the manual barcode field below.'}</div>}
    </div>
    {error && <p className="mobile-barcode-scanner__error" role="alert">{error}</p>}
    <div className="mobile-barcode-scanner__footer"><button type="button" onClick={onClose}>Enter barcode manually</button></div>
  </div>
}
