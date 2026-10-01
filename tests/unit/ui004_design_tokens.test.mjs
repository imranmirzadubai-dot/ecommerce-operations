import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const tokens = fs.readFileSync('src/styles/design-tokens.css', 'utf8')
const index = fs.readFileSync('src/index.css', 'utf8')

test('UI-004 design token layer defines the locked A+B foundation and selective operational semantics', () => {
  for (const token of [
    '--color-neutral-0',
    '--color-accent',
    '--color-success',
    '--color-warning',
    '--color-danger',
    '--color-info',
    '--surface',
    '--text',
    '--border',
    '--focus-ring',
    '--touch-target-min',
    '--breakpoint-tablet',
    '--breakpoint-desktop',
    '--motion-standard',
  ]) assert.ok(tokens.includes(token), token)

  assert.match(tokens, /prefers-reduced-motion/)
  assert.match(tokens, /--touch-target-min: 44px/)
})

test('UI-004 imports tokens globally and adds keyboard-visible focus treatment', () => {
  assert.match(index, /@import ["']\.\/styles\/design-tokens\.css["']/)
  assert.match(index, /button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible/)
  assert.match(index, /outline: 2px solid var\(--focus-ring\)/)
})

test('UI-004 token layer does not encode application workflow or business-state rules', () => {
  assert.doesNotMatch(tokens, /confirm_order|create_order|dispatch_parcel|process_rto|lifecycle_state|supabase|fetch\(/i)
})
