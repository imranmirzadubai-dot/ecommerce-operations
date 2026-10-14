import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

// Characterization test: confirms the current implementation contains two
// same-key writes, so CI stays green while the defect is documented.
// Convert this to an expected-correctness regression test with a mocked
// Worker request path when the implementation fix is separately approved.
const worker = await readFile(new URL('../../worker/index.ts', import.meta.url), 'utf8');

test('orders date range currently overwrites the lower bound', () => {
  const start = worker.indexOf('async function handleOrders');
  const end = worker.indexOf('async function handleOrderTimeline', start);
  assert.notEqual(start, -1, 'handleOrders must exist');
  assert.notEqual(end, -1, 'handleOrderTimeline must follow handleOrders');
  const handler = worker.slice(start, end);

  const dateWrites = [...handler.matchAll(/query\.set\(["']order_date["']/g)];
  assert.equal(dateWrites.length, 2, 'current implementation has two writes to the same order_date key');

  const params = new URLSearchParams();
  params.set('order_date', 'gte.2026-01-10');
  params.set('order_date', 'lte.2026-01-20');
  assert.equal(params.get('order_date'), 'lte.2026-01-20');
  assert.notEqual(params.get('order_date'), 'gte.2026-01-10');

  // Synthetic-only example: with just the upper bound, Jan 5 incorrectly
  // satisfies the constructed filter, despite being before the lower bound.
  const syntheticDates = ['2026-01-05', '2026-01-15', '2026-01-25'];
  const upperBound = params.get('order_date').slice(4);
  assert.deepEqual(syntheticDates.filter(date => date <= upperBound), [
    '2026-01-05',
    '2026-01-15',
  ]);
});
