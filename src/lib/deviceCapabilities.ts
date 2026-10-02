export function shouldShowCameraBarcodeScanner() {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return false

  const userAgent = navigator.userAgent
  const userAgentData = (navigator as Navigator & { userAgentData?: { mobile?: boolean } }).userAgentData

  if (userAgentData?.mobile === true) return true
  if (/Android|iPhone|iPad|iPod|Windows Phone|Mobile/i.test(userAgent)) return true

  // Some tablets, especially iPads using desktop-mode Safari, identify as Mac.
  // Treat a touch device with a tablet-sized viewport as mobile/tablet UI.
  const maxTouchPoints = navigator.maxTouchPoints ?? 0
  const shortestViewportSide = Math.min(window.innerWidth, window.innerHeight)
  return maxTouchPoints > 0 && shortestViewportSide <= 1024
}
