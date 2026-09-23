import { chromium } from 'playwright'
import assert from 'node:assert/strict'

const baseURL = process.env.E2E_BASE_URL
assert.ok(baseURL, 'E2E_BASE_URL is required')

const browser = await chromium.launch({ headless: true })
const context = await browser.newContext()
const page = await context.newPage()

const evidence = {
  test: 'T227-001 clean-main browser reproduction',
  baseURL,
  browser: await browser.version(),
  urlTimeline: [],
  console: [],
  pageerror: [],
  requestfailed: [],
}

page.on('framenavigated', frame => {
  if (frame === page.mainFrame()) evidence.urlTimeline.push(frame.url())
})
page.on('console', msg => evidence.console.push({ type: msg.type(), text: msg.text() }))
page.on('pageerror', error => evidence.pageerror.push(String(error)))
page.on('requestfailed', request => evidence.requestfailed.push({ url: request.url(), failure: request.failure()?.errorText ?? null }))

try {
  await page.goto(baseURL, { waitUntil: 'domcontentloaded', timeout: 30000 })
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {})
  await page.screenshot({ path: 'artifacts/T227-001-clean-main.png', fullPage: true })

  const title = await page.title()
  const bodyText = await page.locator('body').innerText()
  assert.ok(bodyText.length > 0, 'application rendered an empty document')

  console.log(JSON.stringify({ ...evidence, title, bodyTextLength: bodyText.length }, null, 2))
} finally {
  await browser.close()
}
