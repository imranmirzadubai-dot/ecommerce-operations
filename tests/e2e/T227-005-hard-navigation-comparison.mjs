import assert from 'node:assert/strict'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { spawn } from 'node:child_process'

const baseUrl = process.env.E2E_BASE_URL
assert.ok(baseUrl, 'E2E_BASE_URL is required')

await mkdir('artifacts', { recursive: true })
const cases = []
const caseSpecs = [
  ['/', 'root'],
  ['/?t227004=1&orders=off', 'orders-off'],
  ['/?t227004=1&orders=on', 'orders-on'],
]

function runCase(path, name) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, ['tests/e2e/T227-005-hard-navigation-case.mjs', baseUrl, path, name], {
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    let stdout = ''
    let stderr = ''
    let settled = false
    const finish = (result) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      resolve(result)
    }
    child.stdout.on('data', (chunk) => { stdout += chunk.toString() })
    child.stderr.on('data', (chunk) => { stderr += chunk.toString() })
    const timer = setTimeout(() => {
      child.kill('SIGKILL')
      finish({ path, url: `${baseUrl}${path}`, timeout: true, stdout, stderr })
    }, 20000)
    child.on('error', (error) => finish({ path, url: `${baseUrl}${path}`, timeout: false, processError: String(error), stdout, stderr }))
    child.on('exit', async (code, signal) => {
      try {
        const raw = await readFile(`artifacts/T227-005-${name}.json`, 'utf8')
        finish({ ...JSON.parse(raw), processExitCode: code, processSignal: signal })
      } catch {
        finish({ path, url: `${baseUrl}${path}`, timeout: false, processExitCode: code, processSignal: signal, stdout, stderr })
      }
    })
  })
}

for (const [path, name] of caseSpecs) cases.push(await runCase(path, name))

const root = cases[0]
const off = cases[1]
const on = cases[2]
const evidence = {
  test: 'T227-005-hard-navigation-comparison',
  baseUrl,
  browser: 'Chromium',
  cases,
  interpretation: {
    rootRenders: (root?.bodyText?.length ?? 0) > 0,
    ordersOffRenders: off?.markers?.orders === 'off' && (off?.bodyText?.length ?? 0) > 0,
    ordersOnTimedOut: on?.timeout === true,
    ordersOnRenders: on?.markers?.orders === 'on' && (on?.bodyText?.length ?? 0) > 0,
  },
}
await writeFile('artifacts/T227-005-evidence.json', JSON.stringify(evidence, null, 2))
console.log(JSON.stringify(evidence, null, 2))

assert.ok(evidence.interpretation.rootRenders, 'root navigation did not render any body content')
assert.equal(off?.markers?.orders, 'off', 'orders=off control did not render')
assert.equal(off?.navigationError, null, 'orders=off navigation failed')
