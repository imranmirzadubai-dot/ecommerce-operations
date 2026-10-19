import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

test("Orders API sanitizes upstream error bodies and returns a generic gateway error", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(JSON.stringify({
      message: "synthetic internal database detail",
      hint: "synthetic sensitive diagnostic",
      details: "synthetic private metadata",
    }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });

  try {
    const response = await worker.fetch(
      new Request("https://worker.test/api/orders", {
        headers: { Authorization: "Bearer synthetic-test-token" },
      }),
      {
        SUPABASE_URL: "https://supabase.test",
        SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
      },
    );

    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: "upstream_request_failed" });
  } finally {
    globalThis.fetch = originalFetch;
  }
});
