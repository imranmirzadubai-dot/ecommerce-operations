import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const [baseUrl, path, name] = process.argv.slice(2)
if (!baseUrl || !path || !name) throw new Error('baseUrl, path and name are required')

const browser = await chromium.launch({ headless: true, timeout: 10000 })
const page = await browser.newPage()
page.setDefaultTimeout(5000)
page.setDefaultNavigationTimeout(10000)

const result = {
  path,
  url: `${baseUrl}${path}`,
  markers: { orders: null, auth: 0 },
  readyState: null,
  navigationError: null,
  consoleErrors: [],
  pageErrors: [],
  failedRequests: [],
  bodyText: '',
}

page.on('console', (message) => { if (message.type() === 'error') result.consoleErrors.push(message.text()) })
page.on('pageerror', (error) => result.pageErrors.push(String(error)))
page.on('requestfailed', (request) => result.failedRequests.push({ url: request.url(), error: request.failure()?.errorText ?? 'unknown' }))

try {
  await page.goto(result.url, { waitUntil: 'domcontentloaded', timeout: 10000 })
} catch (error) {
  result.navigationError = error instanceof Error ? error.message : String(error)
}

try { result.bodyText = await page.locator('body').innerText({ timeout: 3000 }) } catch {}
try { result.markers.orders = await page.locator('[data-t227004-orders]').getAttribute('data-t227004-orders', { timeout: 3000 }) } catch {}
try { result.markers.auth = await page.locator('[aria-label="Authentication check"]').count() } catch {}
try { result.readyState = await page.evaluate(() => document.readyState) } catch (error) {
  result.readyState = `evaluation-error: ${error instanceof Error ? error.message : String(error)}`
}

await mkdir('artifacts', { recursive: true })
await writeFile(`artifacts/T227-005-${name}.json`, JSON.stringify(result, null, 2))
await page.screenshot({ path: `artifacts/T227-005-${name}.png`, fullPage: false, timeout: 3000 }).catch(() => {})
await page.close({ runBeforeUnload: false }).catch(() => {})
await browser.close().catch(() => {})
