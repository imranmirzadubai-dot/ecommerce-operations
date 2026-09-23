import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.E2E_BASE_URL
const token = 'T227-009-DIAGNOSTIC-TOKEN'
const url = new URL('/api/orders?page=1&page_size=25', baseUrl)
const result = { url: url.toString(), status: null, durationMs: null, bodyPreview: '', contentType: null, requestId: null, browserErrors: [], navigationError: null }

let browser
try {
  browser = await chromium.launch({ headless: true, timeout: 5000, args: ['--no-sandbox', '--disable-dev-shm-usage'] })
  const page = await browser.newPage()
  await page.goto(new URL('/?t227009=1', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 5000 })
  page.on('console', m => { if (m.type() === 'error') result.browserErrors.push(m.text()) })
  page.on('pageerror', e => result.browserErrors.push(String(e)))
  const started = Date.now()
  const response = await page.evaluate(async ({ target, accessToken }) => {
    const startedAt = performance.now()
    try {
      const res = await fetch(target, { headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' }, cache: 'no-store' })
      const text = await res.text()
      return { status: res.status, durationMs: Math.round(performance.now() - startedAt), bodyPreview: text.slice(0, 500), contentType: res.headers.get('content-type'), requestId: res.headers.get('x-request-id') }
    } catch (error) {
      return { error: error instanceof Error ? error.message : String(error), durationMs: Math.round(performance.now() - startedAt) }
    }
  }, { target: url.toString(), accessToken: token })
  result.durationMs = Date.now() - started
  Object.assign(result, response)
} catch (e) {
  result.navigationError = e instanceof Error ? e.message : String(e)
} finally {
  try { await browser?.close() } catch {}
}

await mkdir('artifacts', { recursive: true })
await writeFile('artifacts/T227-009-orders-api-probe.json', JSON.stringify(result, null, 2))
console.log(JSON.stringify(result, null, 2))
if (result.error) process.exitCode = 1
