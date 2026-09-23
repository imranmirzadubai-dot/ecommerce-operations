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

  // Commit only proves that the document response arrived. React may still
  // need a short bounded interval to mount. The previous revision sampled
  // immediately and falsely classified an otherwise healthy page as blank.
  logStage('bounded-render-wait-started')
  const renderDeadline = Date.now() + 6000
  let renderObserved = false
  while (Date.now() < renderDeadline) {
    try {
      const snapshot = await withTimeout(page.evaluate(() => ({
        bodyText: document.body?.innerText ?? '',
        orders: document.querySelector('[data-t227004-orders]')?.getAttribute('data-t227004-orders') ?? null,
        auth: document.querySelectorAll('[aria-label="Authentication check"]').length,
        readyState: document.readyState,
      })), 1200, 'dom-snapshot')
      result.bodyText = snapshot.bodyText
      result.markers.orders = snapshot.orders
      result.markers.auth = snapshot.auth
      result.readyState = snapshot.readyState
      if (snapshot.bodyText.length > 0 || snapshot.orders !== null || snapshot.auth > 0) {
        renderObserved = true
        break
      }
    } catch (error) {
      result.operationTimeout = error instanceof Error ? error.message : String(error)
      break
    }
    await new Promise((resolve) => setTimeout(resolve, 250))
  }

  if (renderObserved) logStage('render-observed')
  else logStage('render-not-observed')

  await mkdir('artifacts', { recursive: true })
  await writeFile(`artifacts/T227-005-${name}.json`, JSON.stringify(result, null, 2))
  logStage('evidence-written')

  // Screenshot is secondary evidence. Never allow it to block the diagnostic.
  try {
    await withTimeout(
      page.screenshot({ path: `artifacts/T227-005-${name}.png`, fullPage: false, timeout: 1500 }),
      2000,
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
  try { await withTimeout(browser?.close() ?? Promise.resolve(), 1500, 'browser.close') } catch {}
}

process.exit(0)
