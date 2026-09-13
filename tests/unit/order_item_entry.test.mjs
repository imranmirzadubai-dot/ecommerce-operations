import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const app = await readFile(new URL('../../src/App.tsx', import.meta.url), 'utf8')

test('draft order UI provides repeatable item description and integer quantity entry', () => {
  assert.match(app, /type OrderItem = \{ description: string; quantity: string \}/)
  assert.match(app, /function addItem\(\)/)
  assert.match(app, /function removeItem\(index: number\)/)
  assert.match(app, /aria-label=\{`Product description \$\{index \+ 1\}`\}/)
  assert.match(app, /placeholder="Product description"/)
  assert.match(app, /aria-label=\{`Quantity \$\{index \+ 1\}`\}/)
  assert.match(app, /type="number" min="1" step="1"/)
  assert.match(app, /Number\.isInteger\(item\.quantity\) && item\.quantity > 0/)
  assert.match(app, /\+ Add item/)
  assert.match(app, /onClick=\{\(\) => removeItem\(index\)\}/)
})
