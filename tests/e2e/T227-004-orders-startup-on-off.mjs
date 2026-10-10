import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.E2E_BASE_URL
assert.ok(baseUrl, 'E2E_BASE_URL is required')

const browser = await chromium.launch({ headless: true })
const cases = []
await mkdir('artifacts', { recursive: true })

try {
  for (const enabled of [false, true]) {
    const workspace = enabled ? 'on' : 'off'
    const url = `${baseUrl}/?t227004=1&orders=${workspace}`
    const page = await browser.newPage()
    const consoleErrors = []
    const pageErrors = []
    const failedRequests = []
    page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
    page.on('pageerror', (error) => pageErrors.push(String(error)))
    page.on('requestfailed', (request) => failedRequests.push({ url: request.url(), error: request.failure()?.errorText ?? 'unknown' }))

    let navigationError = null
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 10000 })
    } catch (error) {
      navigationError = error instanceof Error ? error.message : String(error)
    }

    let bodyText = ''
    try { bodyText = await page.locator('body').innerText({ timeout: 5000 }) } catch {}
    const marker = await page.locator('[data-t227004-orders]').getAttribute('data-t227004-orders').catch(() => null)
    const heading = await page.locator('h1').first().innerText().catch(() => null)

    cases.push({ workspace, url, marker, heading, navigationError, consoleErrors, pageErrors, failedRequests, bodyText })
    await page.screenshot({ path: `artifacts/T227-004-orders-${workspace}.png`, fullPage: true }).catch(() => {})
    await page.close()
  }
} finally {
  await browser.close()
}

const off = cases.find((item) => item.workspace === 'off')
const on = cases.find((item) => item.workspace === 'on')
assert.equal(off?.marker, 'off', 'orders=off control did not mount correctly')
assert.equal(off?.navigationError, null, 'orders=off navigation failed')

const evidence = {
  test: 'T227-004-orders-startup-on-off',
  baseUrl,
  browser: 'Chromium',
  cases,
  interpretation: {
    ordersOffStable: off?.marker === 'off' && off?.navigationError === null && off?.bodyText.length > 0,
    ordersOnStable: on?.marker === 'on' && on?.navigationError === null && on?.bodyText.length > 0,
    ordersOnFailedToRender: on?.marker === null || on?.bodyText.length === 0,
  },
}
await writeFile('artifacts/T227-004-evidence.json', JSON.stringify(evidence, null, 2))

console.log(JSON.stringify(evidence, null, 2))
