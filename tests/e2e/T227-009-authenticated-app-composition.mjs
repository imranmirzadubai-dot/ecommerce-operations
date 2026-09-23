import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.T227009_BASE_URL
if (!baseUrl) throw new Error('T227009_BASE_URL is required')

const cases = [
  { name: 'effect-off', url: `${baseUrl}/?t227009=1&effect=off` },
  { name: 'effect-on', url: `${baseUrl}/?t227009=1&effect=on` },
]

async function runCase(testCase) {
  const browser = await chromium.launch({ headless: true })
  const page = await browser.newPage()
  const consoleErrors = []
  const pageErrors = []
  const failedRequests = []
  let navigationError = null
  page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
  page.on('pageerror', (error) => pageErrors.push(String(error)))
  page.on('requestfailed', (request) => failedRequests.push({ url: request.url(), failure: request.failure()?.errorText ?? 'unknown' }))

  // Controlled authenticated-session simulation: only auth profile is mocked.
  await page.addInitScript(() => {
    localStorage.setItem('ecommerce-operations.auth.session', JSON.stringify({
      accessToken: 'T227-009-DIAGNOSTIC-TOKEN',
      refreshToken: 'T227-009-DIAGNOSTIC-REFRESH',
      expiresAt: Date.now() + 3600000,
      userId: '00000000-0000-0000-0000-000000000009',
    }))
  })
  await page.route('**/rest/v1/profiles?id=eq.*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{
        id: '00000000-0000-0000-0000-000000000009',
        name: 'T227-009 Diagnostic User',
        email: 't227009@example.invalid',
        role: 'admin',
        active: true,
      }]),
    })
  })

  try {
    await page.goto(testCase.url, { waitUntil: 'commit', timeout: 7000 })
  } catch (error) {
    navigationError = String(error)
  }

  let snapshot = null
  try {
    snapshot = await page.evaluate(async () => {
      const started = Date.now()
      while (Date.now() - started < 6000) {
        const body = document.body?.innerText ?? ''
        const marker = document.querySelector('[data-t227009-authenticated]')?.getAttribute('data-t227009-authenticated') ?? null
        if (body.trim() || marker) break
        await new Promise((resolve) => setTimeout(resolve, 100))
      }
      return {
        readyState: document.readyState,
        body: document.body?.innerText ?? '',
        marker: document.querySelector('[data-t227009-authenticated]')?.getAttribute('data-t227009-authenticated') ?? null,
      }
    })
  } catch (error) {
    snapshot = { evaluateError: String(error) }
  }

  const result = {
    name: testCase.name,
    url: testCase.url,
    navigationError,
    consoleErrors,
    pageErrors,
    failedRequests,
    snapshot,
    renders: Boolean(snapshot?.body?.trim()) && snapshot?.marker === 'true',
  }
  await page.screenshot({ path: `artifacts/T227-009-${testCase.name}.png`, fullPage: true, timeout: 2000 }).catch(() => undefined)
  await browser.close().catch(() => undefined)
  return result
}

await mkdir('artifacts', { recursive: true })
const results = []
for (const testCase of cases) results.push(await runCase(testCase))
const evidence = {
  experiment: 'T227-009 authenticated App composition isolation',
  results,
  interpretation: {
    effectOffRenders: results[0].renders,
    effectOnRenders: results[1].renders,
    differentialFailure: results[0].renders !== results[1].renders,
  },
}
await writeFile('artifacts/T227-009-evidence.json', JSON.stringify(evidence, null, 2))
console.log(JSON.stringify(evidence, null, 2))
if (!results[0].renders) process.exit(1)
