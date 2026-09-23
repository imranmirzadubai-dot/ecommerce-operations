import assert from 'node:assert/strict'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { spawn } from 'node:child_process'

const baseUrl = process.env.E2E_BASE_URL
assert.ok(baseUrl, 'E2E_BASE_URL is required')
await mkdir('artifacts', { recursive: true })
const specs = [['/?t227006=1&strict=off', 'strict-off'], ['/?t227006=1&strict=on', 'strict-on']]

function runCase(path, name) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, ['tests/e2e/T227-006-strictmode-case.mjs', baseUrl, path, name], { stdio: ['ignore', 'pipe', 'pipe'] })
    let stdout = '', stderr = '', settled = false
    const finish = result => { if (settled) return; settled = true; clearTimeout(timer); resolve(result) }
    child.stdout.on('data', c => { stdout += c.toString() }); child.stderr.on('data', c => { stderr += c.toString() })
    const timer = setTimeout(() => { child.kill('SIGKILL'); finish({ path, url: baseUrl + path, timeout: true, stdout, stderr }) }, 20000)
    child.on('error', e => finish({ path, url: baseUrl + path, timeout: false, processError: String(e), stdout, stderr }))
    child.on('exit', async (code, signal) => {
      try { finish({ ...(JSON.parse(await readFile(`artifacts/T227-006-${name}.json`, 'utf8'))), processExitCode: code, processSignal: signal }) }
      catch { finish({ path, url: baseUrl + path, timeout: false, processExitCode: code, processSignal: signal, stdout, stderr }) }
    })
  })
}

const cases = []
for (const [path, name] of specs) cases.push(await runCase(path, name))
const off = cases[0], on = cases[1]
const evidence = {
  test: 'T227-006-strictmode-layout-effect-comparison',
  baseUrl,
  browser: 'Chromium',
  cases,
  interpretation: {
    strictOffRenders: off?.markers?.strict === 'off' && (off?.bodyText?.length ?? 0) > 0,
    strictOnRenders: on?.markers?.strict === 'on' && (on?.bodyText?.length ?? 0) > 0,
    strictOffTimedOut: off?.timeout === true || Boolean(off?.operationTimeout),
    strictOnTimedOut: on?.timeout === true || Boolean(on?.operationTimeout),
    differentialFailure: off?.markers?.strict === 'off' && (off?.bodyText?.length ?? 0) > 0 && !(on?.markers?.strict === 'on' && (on?.bodyText?.length ?? 0) > 0),
  },
}
await writeFile('artifacts/T227-006-evidence.json', JSON.stringify(evidence, null, 2))
console.log(JSON.stringify(evidence, null, 2))
assert.equal(off?.markers?.strict, 'off', 'StrictMode OFF control did not render')
assert.equal(off?.navigationError, null, 'StrictMode OFF navigation failed')
assert.ok((off?.bodyText?.length ?? 0) > 0, 'StrictMode OFF produced no rendered body')
