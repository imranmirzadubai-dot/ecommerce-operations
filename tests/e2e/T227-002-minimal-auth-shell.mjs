import { chromium } from 'playwright'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'

const baseURL = process.env.E2E_BASE_URL
if (!baseURL) throw new Error('E2E_BASE_URL is required')

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage()
const evidence = {
  test: 'T227-002 minimal auth shell',
  baseURL,
  browserVersion: browser.version(),
  urlTimeline: [],
  console: [],
  pageErrors: [],
  requestFailed: [],
}

page.on('framenavigated', (frame) => {
  if (frame === page.mainFrame()) evidence.urlTimeline.push(frame.url())
})
page.on('console', (message) => evidence.console.push({ type: message.type(), text: message.text() }))
page.on('pageerror', (error) => evidence.pageErrors.push(String(error)))
page.on('requestfailed', (request) => evidence.requestFailed.push({ url: request.url(), failure: request.failure()?.errorText ?? 'unknown' }))

try {
  await page.goto(`${baseURL.replace(/\/$/, '')}/login`, { waitUntil: 'domcontentloaded' })
  await page.getByTestId('auth-shell-loading').waitFor({ state: 'attached' })
  await page.waitForFunction(() => document.querySelector('[data-testid="auth-shell-loading"]')?.textContent === 'false')

  assert.equal(await page.getByTestId('auth-shell-loading').textContent(), 'false')
  assert.equal(await page.getByTestId('auth-shell-authenticated').textContent(), 'false')
  assert.equal(await page.getByTestId('auth-shell-operational').textContent(), 'false')
  assert.match(await page.getByTestId('auth-shell-status').textContent(), /No active authenticated session\./)
  assert.equal(evidence.pageErrors.length, 0)
  assert.equal(evidence.requestFailed.length, 0)

  await mkdir('artifacts', { recursive: true })
  evidence.title = await page.title()
  evidence.bodyText = await page.locator('body').innerText()
  evidence.dom = await page.locator('body').evaluate((node) => node.outerHTML)
  await writeFile('artifacts/T227-002-evidence.json', JSON.stringify(evidence, null, 2))
  await page.screenshot({ path: 'artifacts/T227-002-minimal-auth-shell.png', fullPage: true })
} catch (error) {
  await mkdir('artifacts', { recursive: true })
  evidence.failure = String(error)
  evidence.bodyText = await page.locator('body').innerText().catch(() => '')
  await writeFile('artifacts/T227-002-evidence.json', JSON.stringify(evidence, null, 2))
  await page.screenshot({ path: 'artifacts/T227-002-minimal-auth-shell-failure.png', fullPage: true }).catch(() => undefined)
  throw error
} finally {
  await browser.close()
}
