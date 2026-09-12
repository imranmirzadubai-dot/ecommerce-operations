import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const root = process.cwd()

test('repository contains the Supabase migration structure', () => {
  assert.equal(existsSync(`${root}/supabase/migrations`), true)
})

test('Supabase seed entrypoint is present and repeatable-safe', () => {
  const seed = readFileSync(`${root}/supabase/seed.sql`, 'utf8')
  assert.match(seed, /SELECT 1;/)
  assert.doesNotMatch(seed, /service[_-]?role|supabase_secret|password/i)
})

test('required repository test directories exist', () => {
  for (const directory of ['tests/unit', 'tests/integration', 'tests/e2e']) {
    assert.equal(existsSync(`${root}/${directory}`), true, directory)
  }
})
