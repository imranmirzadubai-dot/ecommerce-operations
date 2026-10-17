import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

test("admin invite rejects email addresses longer than 254 characters before upstream calls", async () => {
  const originalFetch = globalThis.fetch;
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls += 1;
    throw new Error("unexpected upstream request");
  };

  try {
    const email = `${"a".repeat(244)}@example.com`;
    assert.ok(email.length > 254);
    const response = await worker.fetch(
      new Request("https://worker.test/api/admin/users/invite", {
        method: "POST",
        headers: {
          Authorization: "Bearer synthetic-test-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, name: "Synthetic User", role: "operations" }),
      }),
      {
        SUPABASE_URL: "https://supabase.test",
        SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
        SUPABASE_SECRET_KEY: "test-secret-key",
      },
    );

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: "invalid_email" });
    assert.equal(upstreamCalls, 0, "invalid input must be rejected before any upstream request");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
