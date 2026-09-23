import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.E2E_BASE_URL
const cacheBust = process.env.GITHUB_SHA ?? Date.now().toString()

function orderFixture(index) {
  return {
    id: `00000000-0000-4000-8000-${String(index).padStart(12, '0')}`,
    order_number: `ORD-T227008-${String(index).padStart(3, '0')}`,
    lifecycle_state: index % 2 === 0 ? 'Draft' : 'Confirmed',
    original_amount: 149.5 + index,
    notes: index === 1 ? 'Diagnostic order' : null,
    order_date: '2026-09-23',
    created_at: '2026-09-23T10:00:00.000Z',
    updated_at: '2026-09-23T10:00:00.000Z',
    customers: {
      id: `10000000-0000-4000-8000-${String(index).padStart(12, '0')}`,
      name: `Test Customer ${index}`,
      phone: `0500000${String(index).padStart(3, '0')}`,
      address: 'Diagnostic Street',
      city: 'Dubai',
    },
    order_items: [
      { id: `20000000-0000-4000-8000-${String(index).padStart(12, '0')}`, line_no: 1, description: 'Test Product A', quantity: 2 },
      { id: `30000000-0000-4000-8000-${String(index).padStart(12, '0')}`, line_no: 2, description: 'Test Product B', quantity: 1 },
    ],
  }
}

const cases = [
  { name: 'one-row', rows: 1 },
  { name: 'twenty-five-rows', rows: 25 },
]
const results = []

for (const c of cases) {
  const result = {
    name: c.name,
    rows: c.rows,
    url: null,
    marker: null,
    bodyText: '',
    readyState: null,
    navigationError: null,
    consoleErrors: [],
    pageErrors: [],
    failedRequests: [],
    ordersRequestCount: 0,
    fixtureOrderVisible: false,
  }
  let browser
  try {
    const requestUrl = new URL('/?t227008=1', baseUrl)
    requestUrl.searchParams.set('rows', String(c.rows))
    requestUrl.searchParams.set('t227008cb', cacheBust)
    result.url = requestUrl.toString()

    browser = await chromium.launch({ headless: true, timeout: 5000, args: ['--no-sandbox', '--disable-dev-shm-usage'] })
    const page = await browser.newPage()
    page.setDefaultTimeout(2000)
    page.setDefaultNavigationTimeout(5000)
    page.on('console', m => { if (m.type() === 'error') result.consoleErrors.push(m.text()) })
    page.on('pageerror', e => result.pageErrors.push(String(e)))
    page.on('requestfailed', r => result.failedRequests.push({ url: r.url(), error: r.failure()?.errorText ?? 'unknown' }))

    await page.route('**/api/orders?**', async route => {
      result.ordersRequestCount += 1
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'X-Has-More': 'false' },
        body: JSON.stringify(Array.from({ length: c.rows }, (_, i) => orderFixture(i + 1))),
      })
    })

    try {
      await page.goto(result.url, { waitUntil: 'domcontentloaded', timeout: 5000 })
    } catch (e) {
      result.navigationError = e instanceof Error ? e.message : String(e)
    }

    const deadline = Date.now() + 6000
    while (Date.now() < deadline) {
      try {
        const snapshot = await page.evaluate(() => ({
          bodyText: document.body?.innerText ?? '',
          marker: document.querySelector('[data-t227008-token]')?.getAttribute('data-t227008-token') ?? null,
          readyState: document.readyState,
        }))
        result.bodyText = snapshot.bodyText
        result.marker = snapshot.marker
        result.readyState = snapshot.readyState
        result.fixtureOrderVisible = snapshot.bodyText.includes('ORD-T227008-001')
        if (result.fixtureOrderVisible || snapshot.bodyText.includes('No orders on this page.')) break
      } catch {}
      await new Promise(r => setTimeout(r, 250))
    }
    await mkdir('artifacts', { recursive: true })
    await writeFile(`artifacts/T227-008-${c.name}.json`, JSON.stringify(result, null, 2))
    try { await page.screenshot({ path: `artifacts/T227-008-${c.name}.png`, fullPage: false, timeout: 1500 }) } catch {}
  } catch (e) {
    result.navigationError = e instanceof Error ? e.message : String(e)
  } finally {
    try { await browser?.close() } catch {}
  }
  results.push(result)
}

const interpretation = {
  oneRowRenders: results.find(r => r.rows === 1)?.fixtureOrderVisible === true,
  twentyFiveRowsRenders: results.find(r => r.rows === 25)?.fixtureOrderVisible === true,
  differentialFailure: results.some(r => r.consoleErrors.length || r.pageErrors.length || r.failedRequests.length),
}
console.log(JSON.stringify({ test: 'T227-008-orders-data-render-isolation', baseUrl, browser: 'Chromium', cases: results, interpretation }, null, 2))
