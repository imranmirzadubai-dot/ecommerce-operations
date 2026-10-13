export function buildTrackingLookupUrl(trackingId) {
  if (typeof trackingId !== 'string' || !trackingId.trim()) return null

  const url = new URL('https://www.17track.net/en')
  url.searchParams.set('nums', trackingId.trim())
  return url.toString()
}
