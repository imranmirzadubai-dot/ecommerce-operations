import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

test("orders API includes human-readable parcel_number in parcel embeds", async () => {
  const originalFetch = globalThis.fetch;
  let requestedUrl;
  globalThis.fetch = async (input) => {
    requestedUrl = new URL(String(input));
    return Response.json([]);
  };
  try {
    const request = new Request("https://worker.test/api/orders", {
      headers: { Authorization: "Bearer synthetic-test-token" },
    });
    const response = await worker.fetch(request, {
      SUPABASE_URL: "https://supabase.test",
      SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
    });
    assert.equal(response.status, 200);
    const select = requestedUrl.searchParams.get("select");
    assert.ok(select);
    assert.match(select, /parcels\(id,parcel_number,state,shipper_id,tracking_id\)/);
    assert.doesNotMatch(select, /parcels\(id,state,shipper_id,tracking_id\)/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
