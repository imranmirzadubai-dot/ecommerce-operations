import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'

const baseURL = process.env.E2E_BASE_URL
assert.ok(baseURL, 'E2E_BASE_URL is required')

await mkdir('artifacts', { recursive: true })

const browser = await chromium.launch({ headless: true })
const context = await browser.newContext()
const page = await context.newPage()
await context.tracing.start({ screenshots: true, snapshots: true, sources: true })

const evidence = {
  test: 'T227-001 clean-main browser reproduction',
  baseURL,
  browser: await browser.version(),
  urlTimeline: [],
  lifecycle: [],
  console: [],
  pageerror: [],
  requestfailed: [],
}

page.on('framenavigated', frame => {
  if (frame === page.mainFrame()) evidence.urlTimeline.push({ event: 'framenavigated', url: frame.url(), at: new Date().toISOString() })
})
page.on('console', msg => evidence.console.push({ type: msg.type(), text: msg.text() }))
page.on('pageerror', error => evidence.pageerror.push(String(error)))
page.on('requestfailed', request => evidence.requestfailed.push({ url: request.url(), failure: request.failure()?.errorText ?? null }))

const lifecycle = async event => evidence.lifecycle.push({ event, at: new Date().toISOString(), url: page.url() })

try {
  await lifecycle('goto:start')
  await page.goto(baseURL, { waitUntil: 'domcontentloaded', timeout: 30000 })
  await lifecycle('domcontentloaded')
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => lifecycle('networkidle:timeout'))
  await lifecycle('networkidle:complete')

  const title = await page.title()
  const bodyText = await page.locator('body').innerText()
  const domSnapshot = await page.locator('body').evaluate(node => node.outerHTML)
  const navigation = await page.evaluate(() => {
    const entry = performance.getEntriesByType('navigation')[0]
    return entry ? {
      type: entry.type,
      startTime: entry.startTime,
      domContentLoadedEventEnd: entry.domContentLoadedEventEnd,
      loadEventEnd: entry.loadEventEnd,
      responseStart: entry.responseStart,
      responseEnd: entry.responseEnd,
    } : null
  })

  evidence.title = title
  evidence.bodyTextLength = bodyText.length
  evidence.bodyText = bodyText.slice(0, 12000)
  evidence.domSnapshot = domSnapshot.slice(0, 50000)
  evidence.navigation = navigation

  await page.screenshot({ path: 'artifacts/T227-001-clean-main.png', fullPage: true })
  await writeFile('artifacts/T227-001-evidence.json', JSON.stringify(evidence, null, 2))

  assert.ok(bodyText.length > 0, 'application rendered an empty document')
  console.log(JSON.stringify(evidence, null, 2))
} catch (error) {
  evidence.failure = String(error)
  evidence.failureStack = error?.stack ?? null
  try {
    evidence.failureDomSnapshot = (await page.locator('body').evaluate(node => node.outerHTML)).slice(0, 50000)
    await page.screenshot({ path: 'artifacts/T227-001-clean-main-failure.png', fullPage: true })
  } catch (captureError) {
    evidence.captureError = String(captureError)
  }
  await writeFile('artifacts/T227-001-evidence.json', JSON.stringify(evidence, null, 2))
  throw error
} finally {
  await context.tracing.stop({ path: 'artifacts/T227-001-playwright-trace.zip' }).catch(() => {})
  await browser.close()
}
