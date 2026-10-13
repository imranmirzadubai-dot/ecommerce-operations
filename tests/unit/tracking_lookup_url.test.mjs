import test from 'node:test'
import assert from 'node:assert/strict'
import { buildTrackingLookupUrl } from '../../src/lib/trackingLookup.js'

test('returns no lookup URL when tracking ID is absent or blank', () => {
  assert.equal(buildTrackingLookupUrl(null), null)
  assert.equal(buildTrackingLookupUrl(undefined), null)
  assert.equal(buildTrackingLookupUrl('   '), null)
})

test('trims the tracking ID and uses the fixed HTTPS tracking lookup host', () => {
  const result = buildTrackingLookupUrl('  ABC123  ')
  assert.ok(result)
  const url = new URL(result)
  assert.equal(url.protocol, 'https:')
  assert.equal(url.hostname, 'www.17track.net')
  assert.equal(url.pathname, '/en')
  assert.equal(url.searchParams.get('nums'), 'ABC123')
})

test('encodes tracking IDs as a query parameter rather than URL syntax', () => {
  const result = buildTrackingLookupUrl('AB C/123?x=1')
  assert.ok(result)
  const url = new URL(result)
  assert.equal(url.searchParams.get('nums'), 'AB C/123?x=1')
  assert.equal(url.hostname, 'www.17track.net')
  assert.equal(url.searchParams.has('x'), false)
})
