import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

const env = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
};

const syntheticOrders = [
  { id: "before", order_date: "2026-01-09" },
  { id: "from-boundary", order_date: "2026-01-10" },
  { id: "inside", order_date: "2026-01-15" },
  { id: "to-boundary", order_date: "2026-01-20" },
  { id: "after", order_date: "2026-01-21" },
];

async function requestOrders(search = "") {
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    calls.push({ url: new URL(String(input)), init });
    return Response.json(syntheticOrders);
  };
  try {
    const request = new Request(`https://worker.test/api/orders${search}`, {
      headers: { Authorization: "Bearer synthetic-test-token" },
    });
    const response = await worker.fetch(request, env);
    return { response, calls };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

test("orders date range sends both inclusive bounds to the actual Worker upstream query", async () => {
  const { response, calls } = await requestOrders("?date_from=2026-01-10&date_to=2026-01-20");
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url.origin, "https://supabase.test");
  assert.equal(calls[0].url.pathname, "/rest/v1/orders");
  assert.equal(
    calls[0].url.searchParams.get("and"),
    "(order_date.gte.2026-01-10,order_date.lte.2026-01-20)",
  );
  assert.equal(calls[0].url.searchParams.has("order_date"), false);
});

test("orders date_from alone uses an inclusive lower bound", async () => {
  const { response, calls } = await requestOrders("?date_from=2026-01-10");
  assert.equal(response.status, 200);
  assert.equal(calls[0].url.searchParams.get("order_date"), "gte.2026-01-10");
  assert.equal(calls[0].url.searchParams.has("and"), false);
});

test("orders date_to alone uses an inclusive upper bound", async () => {
  const { response, calls } = await requestOrders("?date_to=2026-01-20");
  assert.equal(response.status, 200);
  assert.equal(calls[0].url.searchParams.get("order_date"), "lte.2026-01-20");
  assert.equal(calls[0].url.searchParams.has("and"), false);
});

test("same-day date range sends equal inclusive lower and upper bounds", async () => {
  const { response, calls } = await requestOrders("?date_from=2026-01-15&date_to=2026-01-15");
  assert.equal(response.status, 200);
  assert.equal(
    calls[0].url.searchParams.get("and"),
    "(order_date.gte.2026-01-15,order_date.lte.2026-01-15)",
  );
});

test("reversed date range is rejected before any upstream request", async () => {
  const { response, calls } = await requestOrders("?date_from=2026-01-21&date_to=2026-01-10");
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: "invalid_date_range",
    message: "date_from and date_to must be valid dates with date_from <= date_to",
  });
  assert.equal(calls.length, 0);
});

test("malformed and impossible dates are rejected before any upstream request", async (t) => {
  for (const query of [
    "?date_from=2026-1-10",
    "?date_to=not-a-date",
    "?date_from=2026-02-30",
  ]) {
    await t.test(query, async () => {
      const { response, calls } = await requestOrders(query);
      assert.equal(response.status, 400);
      assert.equal(calls.length, 0);
    });
  }
});
