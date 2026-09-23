import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'
import { chromium } from 'playwright'

const baseUrl = process.env.E2E_BASE_URL
assert.ok(baseUrl, 'E2E_BASE_URL is required')

const cases = [
  ['none', 'Controlled workspace mount'],
  ['customers', 'Customer History'],
  ['dispatch', 'Scan-first Dispatch'],
  ['rto', 'Scan-first RTO'],
  ['orders', 'Recent Orders'],
]

await mkdir('artifacts', { recursive: true })
const browser = await chromium.launch({ headless: true })
const results = []

try {
  for (const [workspace, expectedHeading] of cases) {
    const page = await browser.newPage()
    const consoleErrors = []
    const pageErrors = []
    const failedRequests = []
    const url = `${baseUrl.replace(/\/$/, '')}/?workspace=${workspace}`

    page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
    page.on('pageerror', (error) => pageErrors.push(error.message))
    page.on('requestfailed', (request) => failedRequests.push({ url: request.url(), failure: request.failure()?.errorText ?? 'unknown' }))

    const startedAt = new Date().toISOString()
    let navigationError = null
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 })
      await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {})
      await page.waitForTimeout(1000)
    } catch (error) {
      navigationError = error instanceof Error ? error.message : String(error)
    }

    const bodyText = await page.locator('body').innerText().catch(() => '')
    const workspaceMarker = await page.locator('[data-t227003-workspace]').getAttribute('data-t227003-workspace').catch(() => null)
    const headingFound = bodyText.includes(expectedHeading)
    const result = {
      workspace, url, expectedHeading, headingFound, workspaceMarker,
      navigationError, consoleErrors, pageErrors, failedRequests,
      bodyText: bodyText.slice(0, 4000), startedAt, completedAt: new Date().toISOString(),
    }
    results.push(result)
    await page.screenshot({ path: `artifacts/T227-003-${workspace}.png`, fullPage: true }).catch(() => {})
    await page.close()
  }
} finally {
  await browser.close()
}

const evidence = {
  test: 'T227-003-workspace-isolation-matrix',
  baseUrl,
  browser: 'Chromium',
  cases: results,
  summary: results.map(({ workspace, headingFound, navigationError, consoleErrors, pageErrors, failedRequests }) => ({ workspace, headingFound, navigationError, consoleErrors: consoleErrors.length, pageErrors: pageErrors.length, failedRequests: failedRequests.length })),
}
await writeFile('artifacts/T227-003-evidence.json', JSON.stringify(evidence, null, 2))

for (const result of results) {
  assert.equal(result.navigationError, null, `${result.workspace}: navigation failed`)
  assert.equal(result.workspaceMarker, result.workspace, `${result.workspace}: workspace marker mismatch`)
  assert.equal(result.headingFound, true, `${result.workspace}: expected workspace heading not rendered`)
  assert.equal(result.pageErrors.length, 0, `${result.workspace}: page error detected: ${result.pageErrors.join('; ')}`)
}
