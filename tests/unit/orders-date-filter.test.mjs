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

import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../../worker/index.ts';

test('Worker orders handler currently drops date_from when date_to is also supplied', async () => {
  const originalFetch = globalThis.fetch;
  const requests = [];
  const syntheticRows = [
    { id: 'before', order_date: '2026-01-05' },
    { id: 'inside', order_date: '2026-01-15' },
    { id: 'after', order_date: '2026-01-25' },
  ];

  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    requests.push(url);
    // Synthetic PostgREST stand-in: apply only the query filters actually
    // sent by the Worker. No network request or real order data is involved.
    const filter = url.searchParams.get('order_date');
    let rows = syntheticRows;
    if (filter?.startsWith('gte.')) rows = rows.filter(row => row.order_date >= filter.slice(4));
    if (filter?.startsWith('lte.')) rows = rows.filter(row => row.order_date <= filter.slice(4));
    return Response.json(rows);
  };

  try {
    const response = await worker.fetch(
      new Request('https://worker.test/api/orders?date_from=2026-01-10&date_to=2026-01-20', {
        headers: { Authorization: 'Bearer synthetic-test-token' },
      }),
      { SUPABASE_URL: 'https://supabase.invalid', SUPABASE_PUBLISHABLE_KEY: 'synthetic-publishable-key' },
    );

    assert.equal(response.status, 200);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].origin, 'https://supabase.invalid');
    assert.equal(requests[0].pathname, '/rest/v1/orders');
    assert.equal(requests[0].searchParams.get('order_date'), 'lte.2026-01-20');
    assert.deepEqual((await response.json()).map(row => row.id), ['before', 'inside']);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
