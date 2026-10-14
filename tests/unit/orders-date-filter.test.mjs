import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

// This is a source-level regression guard, not a Worker integration test.
// It intentionally fails while the known duplicate-key overwrite remains.
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8');

test('orders date range preserves both lower and upper bounds', () => {
  const start = worker.indexOf('async function handleOrders');
  const end = worker.indexOf('async function handleOrderTimeline', start);
  assert.notEqual(start, -1, 'handleOrders must exist');
  assert.notEqual(end, -1, 'handleOrderTimeline must follow handleOrders');
  const handler = worker.slice(start, end);

  // Two URLSearchParams.set() calls on the same key overwrite one another.
  // Keep this guard implementation-neutral: the eventual fix may use a
  // combined PostgREST expression or another explicit range representation.
  const dateRangeUsesSingleKey = /query\.set\(["']order_date["']/.test(handler);
  const hasCombinedRange = /query\.set\(["']and["']/.test(handler)
    && /order_date\.gte\./.test(handler)
    && /order_date\.lte\./.test(handler);
  const usesSeparateDateFilterBuilder = /buildOrderDateRangeFilter\(/.test(handler);

  assert.ok(
    !dateRangeUsesSingleKey || hasCombinedRange || usesSeparateDateFilterBuilder,
    'date_from and date_to must be combined without overwriting either bound',
  );
});
