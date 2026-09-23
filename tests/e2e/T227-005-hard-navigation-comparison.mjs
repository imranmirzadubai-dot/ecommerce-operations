import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.E2E_BASE_URL
assert.ok(baseUrl, 'E2E_BASE_URL is required')

const browser = await chromium.launch({ headless: true, timeout: 10000 })
const cases = []
await mkdir('artifacts', { recursive: true })

async function captureCase(path, name) {
  const page = await browser.newPage()
  const consoleErrors = []
  const pageErrors = []
  const failedRequests = []
  page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
  page.on('pageerror', (error) => pageErrors.push(String(error)))
  page.on('requestfailed', (request) => failedRequests.push({ url: request.url(), error: request.failure()?.errorText ?? 'unknown' }))

  let navigationError = null
  try {
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'domcontentloaded', timeout: 10000 })
  } catch (error) {
    navigationError = error instanceof Error ? error.message : String(error)
  }

  // Do not use locator auto-waiting here: a blank-page diagnostic must itself
  // remain bounded and must always produce evidence for the next investigation.
  const snapshot = await page.evaluate(() => ({
    bodyText: document.body?.innerText ?? '',
    orders: document.querySelector('[data-t227004-orders]')?.getAttribute('data-t227004-orders') ?? null,
    auth: document.querySelectorAll('[aria-label="Authentication check"]').length,
    readyState: document.readyState,
  })).catch((error) => ({
    bodyText: '',
    orders: null,
    auth: 0,
    readyState: `evaluation-error: ${error instanceof Error ? error.message : String(error)}`,
  }))

  const screenshotPath = `artifacts/T227-005-${name}.png`
  await page.screenshot({ path: screenshotPath, fullPage: true, timeout: 5000 }).catch(() => {})
  cases.push({
    path,
    url: `${baseUrl}${path}`,
    markers: { orders: snapshot.orders, auth: snapshot.auth },
    readyState: snapshot.readyState,
    navigationError,
    consoleErrors,
    pageErrors,
    failedRequests,
    bodyText: snapshot.bodyText,
  })
  await page.close({ runBeforeUnload: false }).catch(() => {})
}

try {
  await captureCase('/', 'root')
  await captureCase('/?t227004=1&orders=off', 'orders-off')
  await captureCase('/?t227004=1&orders=on', 'orders-on')
} finally {
  await browser.close().catch(() => {})
}

const root = cases[0]
const off = cases[1]
const on = cases[2]
assert.ok((root?.bodyText.length ?? 0) > 0, 'root navigation did not render any body content')
assert.equal(off?.markers.orders, 'off', 'orders=off control did not render')
assert.equal(off?.navigationError, null, 'orders=off navigation failed')
assert.equal(on?.navigationError, null, 'orders=on navigation itself failed')

const evidence = {
  test: 'T227-005-hard-navigation-comparison',
  baseUrl,
  browser: 'Chromium',
  cases,
  interpretation: {
    rootRenders: (root?.bodyText.length ?? 0) > 0,
    ordersOffRenders: off?.markers.orders === 'off' && (off?.bodyText.length ?? 0) > 0,
    ordersOnNavigationSucceeds: on?.navigationError === null,
    ordersOnRenders: on?.markers.orders === 'on' && (on?.bodyText.length ?? 0) > 0,
  },
}
await writeFile('artifacts/T227-005-evidence.json', JSON.stringify(evidence, null, 2))
console.log(JSON.stringify(evidence, null, 2))
