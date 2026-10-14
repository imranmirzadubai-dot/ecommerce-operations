import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../../worker/index.ts';

test('orders date range preserves both lower and upper bounds', async () => {
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
    const range = url.searchParams.get('and');
    let rows = syntheticRows;
    if (range) {
      const lower = range.match(/order_date\.gte\.([^,)]+)/)?.[1];
      const upper = range.match(/order_date\.lte\.([^,)]+)/)?.[1];
      if (lower) rows = rows.filter(row => row.order_date >= lower);
      if (upper) rows = rows.filter(row => row.order_date <= upper);
    } else {
      const filter = url.searchParams.get('order_date');
      if (filter?.startsWith('gte.')) rows = rows.filter(row => row.order_date >= filter.slice(4));
      if (filter?.startsWith('lte.')) rows = rows.filter(row => row.order_date <= filter.slice(4));
    }
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
    assert.equal(requests[0].searchParams.get('and'), '(order_date.gte.2026-01-10,order_date.lte.2026-01-20)');
    assert.equal(requests[0].searchParams.has('order_date'), false);
    assert.deepEqual((await response.json()).map(row => row.id), ['inside']);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('orders date filter uses a single bound when only one date is supplied', async () => {
  const originalFetch = globalThis.fetch;
  const requests = [];
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    requests.push(url);
    return Response.json([]);
  };

  try {
    const response = await worker.fetch(
      new Request('https://worker.test/api/orders?date_from=2026-01-10', {
        headers: { Authorization: 'Bearer synthetic-test-token' },
      }),
      { SUPABASE_URL: 'https://supabase.invalid', SUPABASE_PUBLISHABLE_KEY: 'synthetic-publishable-key' },
    );
    assert.equal(response.status, 200);
    assert.equal(requests[0].searchParams.get('order_date'), 'gte.2026-01-10');
    assert.equal(requests[0].searchParams.has('and'), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
