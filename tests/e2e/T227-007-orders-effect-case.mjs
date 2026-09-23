import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'
const [baseUrl, path, name] = process.argv.slice(2)
const result = { path, url: baseUrl + path, stage: 'starting', markers: { effect: null }, locationHref: null, locationSearch: null, scriptUrls: [], bundleHasDiagnosticMarker: null, readyState: null, navigationError: null, consoleErrors: [], pageErrors: [], failedRequests: [], bodyText: '', operationTimeout: null }
const logStage = stage => { result.stage = stage; process.stdout.write(`[T227-007 ${name}] ${stage}\n`) }
const withTimeout = async (promise, ms, label) => { let timer; try { return await Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms) })]) } finally { clearTimeout(timer) } }
let browser
try {
  logStage('launching-browser')
  browser = await withTimeout(chromium.launch({ headless: true, timeout: 5000, args: ['--no-sandbox', '--disable-dev-shm-usage'] }), 7000, 'chromium.launch')
  logStage('browser-launched')
  const page = await withTimeout(browser.newPage(), 3000, 'browser.newPage'); logStage('page-created')
  page.setDefaultTimeout(2000); page.setDefaultNavigationTimeout(5000)
  page.on('console', m => { if (m.type() === 'error') result.consoleErrors.push(m.text()) }); page.on('pageerror', e => result.pageErrors.push(String(e)))
  page.on('requestfailed', r => result.failedRequests.push({ url: r.url(), error: r.failure()?.errorText ?? 'unknown' }))
  logStage('navigation-started')
  try { await withTimeout(page.goto(result.url, { waitUntil: 'domcontentloaded', timeout: 5000 }), 7000, 'page.goto(domcontentloaded)'); logStage('navigation-complete') }
  catch (e) { result.navigationError = e instanceof Error ? e.message : String(e); logStage('navigation-error') }
  logStage('bounded-render-wait-started')
  const deadline = Date.now() + 6000
  while (Date.now() < deadline) {
    try {
      const s = await withTimeout(page.evaluate(async () => { const scriptUrls = [...document.scripts].map(s => s.src).filter(Boolean); let bundleHasDiagnosticMarker = false; for (const src of scriptUrls) { try { const text = await (await fetch(src, { cache: 'no-store' })).text(); if (text.includes('T227-007-DIAGNOSTIC-TOKEN') || text.includes('t227007')) bundleHasDiagnosticMarker = true } catch {} } return { bodyText: document.body?.innerText ?? '', effect: document.querySelector('[data-t227007-effect]')?.getAttribute('data-t227007-effect') ?? null, readyState: document.readyState, locationHref: window.location.href, locationSearch: window.location.search, scriptUrls, bundleHasDiagnosticMarker } }), 1800, 'dom-snapshot')
      result.bodyText = s.bodyText; result.markers.effect = s.effect; result.readyState = s.readyState; result.locationHref = s.locationHref; result.locationSearch = s.locationSearch; result.scriptUrls = s.scriptUrls; result.bundleHasDiagnosticMarker = s.bundleHasDiagnosticMarker
      if (s.bodyText.length > 0 || s.effect !== null) break
    } catch (e) { result.operationTimeout = e instanceof Error ? e.message : String(e); break }
    await new Promise(r => setTimeout(r, 250))
  }
  logStage(result.bodyText.length > 0 || result.markers.effect !== null ? 'render-observed' : 'render-not-observed')
  await mkdir('artifacts', { recursive: true }); await writeFile(`artifacts/T227-007-${name}.json`, JSON.stringify(result, null, 2)); logStage('evidence-written')
  try { await withTimeout(page.screenshot({ path: `artifacts/T227-007-${name}.png`, fullPage: false, timeout: 1500 }), 2000, 'screenshot') } catch {}
} catch (e) {
  result.operationTimeout = e instanceof Error ? e.message : String(e); await mkdir('artifacts', { recursive: true }); await writeFile(`artifacts/T227-007-${name}.json`, JSON.stringify(result, null, 2)); logStage('fatal-diagnostic-error')
} finally { try { await withTimeout(browser?.close() ?? Promise.resolve(), 1500, 'browser.close') } catch {} }
process.exit(0)
