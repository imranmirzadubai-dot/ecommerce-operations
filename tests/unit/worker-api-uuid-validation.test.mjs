import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

const env = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
};
const malformedUuid = "000000000-000-0000-0000-000000000000";
const validUuid = "123e4567-e89b-42d3-a456-426614174000";

async function requestWithFetchSpy(path) {
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    calls.push(String(input));
    return Response.json([]);
  };
  try {
    const response = await worker.fetch(new Request(`https://worker.test${path}`, {
      headers: { Authorization: "Bearer synthetic-test-token" },
    }), env);
    return { response, calls };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

test("timeline route rejects UUID-shaped identifiers with incorrectly positioned hyphens before upstream access", async () => {
  const { response, calls } = await requestWithFetchSpy(`/api/orders/${malformedUuid}/timeline`);
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_order_id" });
  assert.equal(calls.length, 0);
});

test("customer history route rejects UUID-shaped identifiers with incorrectly positioned hyphens before upstream access", async () => {
  const { response, calls } = await requestWithFetchSpy(`/api/customers/${malformedUuid}/history`);
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_customer_id" });
  assert.equal(calls.length, 0);
});

test("password recovery rejects malformed UUID structure before any upstream access", async () => {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (input) => {
    calls.push(String(input));
    return Response.json({ id: "synthetic-user" });
  };
  try {
    const response = await worker.fetch(new Request("https://worker.test/api/admin/users/password-recovery", {
      method: "POST",
      headers: {
        Authorization: "Bearer synthetic-test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ userId: malformedUuid }),
    }), { ...env, SUPABASE_SECRET_KEY: "synthetic-secret-key" });
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: "invalid_user_id" });
    assert.equal(calls.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("timeline route accepts a correctly structured UUID and reaches the mocked upstream", async () => {
  const { response, calls } = await requestWithFetchSpy(`/api/orders/${validUuid}/timeline`);
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0], /\/rest\/v1\/order_events\?/);
});
