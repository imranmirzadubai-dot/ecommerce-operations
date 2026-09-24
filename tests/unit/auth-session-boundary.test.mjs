import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const authSource = fs.readFileSync(path.join(root, 'src/lib/auth.ts'), 'utf8')
const workerSource = fs.readFileSync(path.join(root, 'worker/index.ts'), 'utf8')

test('AUTH-004 removes browser storage of authentication sessions', () => {
  assert.doesNotMatch(authSource, /localStorage\.(getItem|setItem)\([^)]*auth\.session/)
  assert.match(authSource, /localStorage\.removeItem\(LEGACY_SESSION_KEY\)/)
  assert.match(authSource, /clearStoredSession\(\)/)
  assert.match(authSource, /credentials: RequestCredentials = 'include'/)
  assert.match(authSource, /\/api\/auth\/session/)
  assert.match(authSource, /\/api\/auth\/sign-in/)
  assert.match(authSource, /\/api\/auth\/sign-out/)
})

test('AUTH-004 uses credentialed requests only for same-origin auth endpoints', () => {
  assert.match(authSource, /async function fetchWithTimeout\([^)]*credentials: RequestCredentials = 'include'\)/)
  assert.match(authSource, /fetch\(input, \{ \.\.\.init, signal: controller\.signal, credentials \}\)/)
  assert.match(authSource, /\/api\/auth\/sign-in/)
  assert.match(authSource, /\/api\/auth\/session/)
  assert.match(authSource, /\/api\/auth\/sign-out/)
})

test('AUTH-004 omits browser credentials on cross-origin Supabase profile fetch', () => {
  assert.match(authSource, /\/rest\/v1\/profiles\?id=eq\.\$\{encodeURIComponent\(userId\)[\s\S]*\}, signal, 'omit'\)/)
})

test('AUTH-004 keeps the refresh token in an HttpOnly Secure cookie', () => {
  assert.match(workerSource, /HttpOnly/)
  assert.match(workerSource, /Secure/)
  assert.match(workerSource, /SameSite=Lax/)
  assert.match(workerSource, /AUTH_COOKIE/)
  assert.doesNotMatch(workerSource, /accessToken.*refreshToken.*localStorage/)
})

test('AUTH-004 refresh endpoint never returns the refresh token to the browser', () => {
  assert.match(workerSource, /return json\(\{ accessToken: token\.access_token, userId: token\.user\.id \}/)
  assert.doesNotMatch(workerSource, /return json\(\{[^}]*refresh_token/)
})

test('AUTH-004 cross-tab fallback uses only a non-secret event marker', () => {
  const contextSource = fs.readFileSync(path.join(root, 'src/lib/AuthContext.tsx'), 'utf8')
  assert.match(contextSource, /SESSION_EVENT_KEY = 'ecommerce-operations\.auth\.event'/)
  assert.match(contextSource, /localStorage\.setItem\(SESSION_EVENT_KEY, crypto\.randomUUID\(\)\)/)
  assert.doesNotMatch(contextSource, /localStorage\.getItem\('ecommerce-operations\.auth\.session'\)/)
})
