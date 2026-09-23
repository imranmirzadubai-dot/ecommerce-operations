import { spawn } from 'node:child_process'
import { mkdir, writeFile } from 'node:fs/promises'

const BASE_URL = process.env.T227008_BASE_URL || 'https://ecommerce-operations-t227008.imranmirzadubai.workers.dev'
const cases = [
  { name: 'effect-off', url: BASE_URL + '/?t227008=1&effect=off' },
  { name: 'effect-on', url: BASE_URL + '/?t227008=1&effect=on' },
]

async function runCase(testCase) {
  const script = `
    const { chromium } = require('playwright')
    ;(async () => {
      const browser = await chromium.launch({ headless: true })
      const page = await browser.newPage()
      const consoleErrors = []
      const pageErrors = []
      const failedRequests = []
      page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()) })
      page.on('pageerror', e => pageErrors.push(String(e)))
      page.on('requestfailed', r => failedRequests.push({ url: r.url(), errorText: r.failure()?.errorText || '' }))
      let navigationError = null
      try { await page.goto(${JSON.stringify(testCase.url)}, { waitUntil: 'commit', timeout: 7000 }) }
      catch (e) { navigationError = String(e) }
      const deadline = Date.now() + 6000
      let snapshot = { body: '', readyState: '', marker: null }
      while (Date.now() < deadline) {
        try {
          snapshot = await page.evaluate(() => ({
            body: document.body?.innerText || '',
            readyState: document.readyState,
            marker: document.querySelector('[data-t227008-app]')?.getAttribute('data-t227008-app') || null
          }))
          if (snapshot.body.trim()) break
        } catch {}
        await new Promise(r => setTimeout(r, 150))
      }
      await browser.close().catch(() => {})
      process.stdout.write(JSON.stringify({
        name: ${JSON.stringify(testCase.name)},
        url: ${JSON.stringify(testCase.url)},
        navigationError, consoleErrors, pageErrors, failedRequests,
        ...snapshot, renders: Boolean(snapshot.body.trim()),
      }))
    })().catch(e => { process.stdout.write(JSON.stringify({ name: ${JSON.stringify(testCase.name)}, fatal: String(e) })); process.exit(0) })
  `
  const child = spawn(process.execPath, ['-e', script], { stdio: ['ignore', 'pipe', 'pipe'] })
  let stdout = '', stderr = ''
  child.stdout.on('data', d => { stdout += d })
  child.stderr.on('data', d => { stderr += d })
  const result = await new Promise(resolve => {
    const timer = setTimeout(() => { child.kill('SIGKILL'); resolve({ timeout: true, stdout, stderr }) }, 20000)
    child.on('close', code => { clearTimeout(timer); resolve({ timeout: false, code, stdout, stderr }) })
  })
  let parsed = null
  try { parsed = JSON.parse(result.stdout.trim()) } catch {}
  return { ...result, parsed }
}

const evidence = []
for (const testCase of cases) evidence.push(await runCase(testCase))
await mkdir('artifacts', { recursive: true })
await writeFile('artifacts/T227-008-evidence.json', JSON.stringify({
  baseUrl: BASE_URL,
  cases: evidence,
  interpretation: {
    effectOffRenders: evidence.find(x => x.parsed?.name === 'effect-off')?.parsed?.renders === true,
    effectOnRenders: evidence.find(x => x.parsed?.name === 'effect-on')?.parsed?.renders === true,
    differentialFailure: evidence.find(x => x.parsed?.name === 'effect-off')?.parsed?.renders === true &&
      evidence.find(x => x.parsed?.name === 'effect-on')?.parsed?.renders !== true,
  },
}, null, 2))
const off = evidence.find(x => x.parsed?.name === 'effect-off')?.parsed
if (!off?.renders) process.exitCode = 1
