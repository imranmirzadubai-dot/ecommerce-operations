import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const reporter = fs.readFileSync('src/lib/errorReporting.ts', 'utf8')
const boundary = fs.readFileSync('src/components/ErrorBoundary.tsx', 'utf8')
const main = fs.readFileSync('src/main.tsx', 'utf8')

test('P14-T216 reports errors through the structured logger', () => {
  assert.match(reporter, /logger\.error\('Unhandled application error'/)
  assert.match(reporter, /error instanceof Error/)
  assert.match(reporter, /name: error\.name/)
  assert.match(reporter, /message: error\.message/)
  assert.match(reporter, /stack: error\.stack/)
})

test('P14-T216 installs global error and rejection handlers with cleanup', () => {
  assert.match(reporter, /addEventListener\('error'/)
  assert.match(reporter, /addEventListener\('unhandledrejection'/)
  assert.match(reporter, /removeEventListener\('error'/)
  assert.match(reporter, /removeEventListener\('unhandledrejection'/)
})

test('P14-T216 protects React rendering with an error boundary', () => {
  assert.match(boundary, /componentDidCatch/)
  assert.match(boundary, /reportError\(error/)
  assert.match(boundary, /Something went wrong/)
  assert.match(boundary, /Reload/) 
  assert.match(main, /<ErrorBoundary>/)
  assert.match(main, /installGlobalErrorReporting/)
})

test('P14-T216 preserves structured logger redaction boundary', () => {
  const logger = fs.readFileSync('src/lib/logger.ts', 'utf8')
  for (const key of ['access_token', 'refresh_token', 'authorization', 'password', 'service_role']) {
    assert.match(logger, new RegExp(key))
  }
  assert.match(logger, /sanitizeValue\(context\)/)
})
