import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

const env = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
};

const sensitiveBody = JSON.stringify({
  message: "synthetic internal database detail",
  hint: "synthetic sensitive diagnostic",
  details: "synthetic private metadata",
});

for (const scenario of [
  {
    name: "RPC command",
    request: () => new Request("https://worker.test/api/commands/create_order", {
      method: "POST",
      headers: { Authorization: "Bearer synthetic-test-token", "Content-Type": "application/json" },
      body: "{}",
    }),
  },
  {
    name: "order timeline",
    request: () => new Request("https://worker.test/api/orders/123e4567-e89b-12d3-a456-426614174000/timeline", {
      headers: { Authorization: "Bearer synthetic-test-token" },
    }),
  },
  {
    name: "customer history",
    request: () => new Request("https://worker.test/api/customers/123e4567-e89b-12d3-a456-426614174000/history", {
      headers: { Authorization: "Bearer synthetic-test-token" },
    }),
  },
]) {
  test(`${scenario.name} sanitizes upstream 5xx response bodies`, async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => new Response(sensitiveBody, {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });

    try {
      const response = await worker.fetch(scenario.request(), env);
      assert.equal(response.status, 502);
      assert.deepEqual(await response.json(), { error: "upstream_request_failed" });
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}
