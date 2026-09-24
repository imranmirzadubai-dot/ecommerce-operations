import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')
const routeGuard = await readFile(new URL('../../src/RouteGuard.tsx', import.meta.url), 'utf8')
const context = await readFile(new URL('../../src/lib/AuthContext.tsx', import.meta.url), 'utf8')


test('auth bootstrap has one owner', () => {
  assert.match(context, /export function AuthProvider/)
  assert.match(context, /restoreSession\(controller\.signal\)/)
  assert.doesNotMatch(app, /restoreSession\(\)/)
  assert.doesNotMatch(routeGuard, /restoreSession\(\)/)
})

test('auth lifecycle schedules refresh before session expiry', () => {
  assert.match(context, /REFRESH_LEAD_MS = 60_000/)
  assert.match(context, /expiresAt - Date\.now\(\) - REFRESH_LEAD_MS/)
  assert.match(context, /window\.setTimeout/) 
  assert.match(context, /void refresh\(\)/)
})

test('sign-out clears the refresh lifecycle', () => {
  assert.match(context, /clearRefreshTimer\(\)/)
  assert.match(context, /await terminateSession\(controller\.signal\)/)
})


test('auth operations own loading state and stale operations cannot settle it', () => {
  assert.match(context, /setLoading\(true\)/)
  assert.match(context, /const finishOperation = useCallback/)
  assert.match(context, /if \(!isCurrentOperation\(generation, controller\)\) return/)
  assert.match(context, /setLoading\(false\)/)
  assert.match(context, /finally \{\n      finishOperation\(generation, controller\)/)
})
