import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const app = fs.readFileSync('src/App.tsx', 'utf8')

test('UI-004 lazy-loads authenticated workspaces and mounts only the active workspace', () => {
  assert.match(app, /lazy\(\(\) => import\('\.\/components\/OrdersWorkspace'\)/)
  assert.match(app, /lazy\(\(\) => import\('\.\/components\/ReportWorkspace'\)/)
  assert.match(app, /const \[activeWorkspace, setActiveWorkspace\] = useState\('Dashboard'\)/)
  assert.match(app, /function navigateTo\(item: string\) \{ setActiveWorkspace\(item\) \}/)
  assert.match(app, /activeWorkspace === 'Orders'/)
  assert.match(app, /activeWorkspace === 'Reports'/)
  assert.match(app, /activeWorkspace === 'Customers'/)
  assert.match(app, /<Suspense fallback=\{<WorkspaceLoading \/>\}>/)
  assert.doesNotMatch(app, /\{authenticated && auth\.accessToken && <CustomerHistoryWorkspace/)
  assert.doesNotMatch(app, /\{authenticated && auth\.accessToken && <DispatchScanWorkspace/)
  assert.doesNotMatch(app, /\{authenticated && auth\.accessToken && <RtoScanWorkspace/)
  assert.doesNotMatch(app, /\{authenticated && auth\.accessToken && <InvoicePrintWorkspace/)
  assert.doesNotMatch(app, /\{authenticated && auth\.accessToken && <ReportWorkspace/)
})
