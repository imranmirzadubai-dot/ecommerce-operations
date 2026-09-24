import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const source = fs.readFileSync(path.join(root, 'src/lib/AuthContext.tsx'), 'utf8')

test('AUTH-003 defines cross-tab storage synchronization', () => {
  assert.match(source, /window\.addEventListener\('storage'/)
  assert.match(source, /event\.key === 'ecommerce-operations\.auth\.session'/)
  assert.match(source, /window\.removeEventListener\('storage'/)
})

test('AUTH-003 uses BroadcastChannel without transmitting session credentials', () => {
  assert.match(source, /new BroadcastChannel\(AUTH_CHANNEL_NAME\)/)
  assert.match(source, /channel\.onmessage/)
  assert.match(source, /postMessage\(SESSION_CHANGED_MESSAGE\)/)
  assert.doesNotMatch(source, /postMessage\([^)]*accessToken/)
  assert.doesNotMatch(source, /postMessage\([^)]*refreshToken/)
})

test('AUTH-003 external session changes use the existing auth operation lifecycle', () => {
  assert.match(source, /const syncExternalSession = useCallback/)
  assert.match(source, /beginOperation\(\)/)
  assert.match(source, /beginUserOperation\(\)/)
  assert.match(source, /finishOperation\(generation, controller\)/)
})
