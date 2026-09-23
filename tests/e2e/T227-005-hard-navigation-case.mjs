import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const [baseUrl, path, name] = process.argv.slice(2)
if (!baseUrl || !path || !name) throw new Error('baseUrl, path and name are required')

const result = {
  path,
  url: `${baseUrl}${path}`,
  stage: 'starting',
  markers: { orders: null, auth: 0 },
  readyState: null,
  navigationError: null,
  consoleErrors: [],
  pageErrors: [],
  failedRequests: [],
  bodyText: '',
  operationTimeout: null,
}

const logStage = (stage) => {
  result.stage = stage
  process.stdout.write(`[T227-005 ${name}] ${stage}\n`)
}

const withTimeout = async (promise, ms, label) => {
  let timer
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)
      }),
    ])
  } finally {
    clearTimeout(timer)
  }
}

let browser
try {
  logStage('launching-browser')
  browser = await withTimeout(
    chromium.launch({
      headless: true,
      timeout: 5000,
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    }),
    7000,
    'chromium.launch',
  )
  logStage('browser-launched')

  const page = await withTimeout(browser.newPage(), 3000, 'browser.newPage')
  logStage('page-created')
  page.setDefaultTimeout(2000)
  page.setDefaultNavigationTimeout(5000)

  page.on('console', (message) => { if (message.type() === 'error') result.consoleErrors.push(message.text()) })
  page.on('pageerror', (error) => result.pageErrors.push(String(error)))
  page.on('requestfailed', (request) => result.failedRequests.push({ url: request.url(), error: request.failure()?.errorText ?? 'unknown' }))

  logStage('navigation-started')
  try {
    // `commit` deliberately stops at the network commit boundary. We do not
    // wait for DOMContentLoaded because the suspected Orders defect may block
    // the renderer before that lifecycle event can be observed.
    await withTimeout(
      page.goto(result.url, { waitUntil: 'commit', timeout: 5000 }),
      7000,
      'page.goto(commit)',
    )
    logStage('navigation-committed')
  } catch (error) {
    result.navigationError = error instanceof Error ? error.message : String(error)
    logStage('navigation-error')
  }

  const snapshot = async () => page.evaluate(() => ({
    bodyText: document.body?.innerText ?? '',
    orders: document.querySelector('[data-t227004-orders]')?.getAttribute('data-t227004-orders') ?? null,
    auth: document.querySelectorAll('[aria-label="Authentication check"]').length,
    readyState: document.readyState,
  }))

  logStage('dom-snapshot-started')
  try {
    const value = await withTimeout(snapshot(), 2500, 'dom-snapshot')
    result.bodyText = value.bodyText
    result.markers.orders = value.orders
    result.markers.auth = value.auth
    result.readyState = value.readyState
    logStage('dom-snapshot-complete')
  } catch (error) {
    result.operationTimeout = error instanceof Error ? error.message : String(error)
    logStage('dom-snapshot-timeout')
  }

  await mkdir('artifacts', { recursive: true })
  await writeFile(`artifacts/T227-005-${name}.json`, JSON.stringify(result, null, 2))
  logStage('evidence-written')

  // Screenshot is secondary evidence. Never allow it to block the diagnostic.
  try {
    await withTimeout(
      page.screenshot({ path: `artifacts/T227-005-${name}.png`, fullPage: false, timeout: 2000 }),
      2500,
      'screenshot',
    )
  } catch (error) {
    result.operationTimeout ??= error instanceof Error ? error.message : String(error)
    await writeFile(`artifacts/T227-005-${name}.json`, JSON.stringify(result, null, 2))
  }
} catch (error) {
  result.operationTimeout = error instanceof Error ? error.message : String(error)
  await mkdir('artifacts', { recursive: true })
  await writeFile(`artifacts/T227-005-${name}.json`, JSON.stringify(result, null, 2))
  logStage('fatal-diagnostic-error')
} finally {
  // Cleanup is deliberately best-effort. The parent process already enforces
  // a hard case deadline; never let browser shutdown hide the evidence.
  try { await withTimeout(browser?.close() ?? Promise.resolve(), 2000, 'browser.close') } catch {}
}

process.exit(0)
