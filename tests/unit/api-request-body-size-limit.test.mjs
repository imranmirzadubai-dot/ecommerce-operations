import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

const env = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
};

test("rejects request bodies over 1 MiB even without Content-Length", async () => {
  const originalFetch = globalThis.fetch;
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls += 1;
    throw new Error("Oversized body must be rejected before any upstream request");
  };

  try {
    const body = JSON.stringify({ refreshToken: "x".repeat(1024 * 1024) });
    const response = await worker.fetch(
      new Request("https://worker.test/api/auth/invite-session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      }),
      env,
    );
    assert.equal(response.status, 413);
    assert.deepEqual(await response.json(), {
      error: "request_body_too_large",
      message: "Request body must not exceed 1 MiB",
    });
    assert.equal(upstreamCalls, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rejects declared oversized request bodies before reading them", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/api/auth/invite-session", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": String(1024 * 1024 + 1),
      },
      body: "{}",
    }),
    env,
  );
  assert.equal(response.status, 413);
});
