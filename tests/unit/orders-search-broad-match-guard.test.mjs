import test from "node:test";
import assert from "node:assert/strict";
import worker from "../../worker/index.ts";

const env = {
  SUPABASE_URL: "https://supabase.test",
  SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
};

const customers = Array.from({ length: 101 }, (_, index) => ({
  id: `123e4567-e89b-42d3-a456-${String(index).padStart(12, "0")}`,
}));
const items = Array.from({ length: 101 }, (_, index) => ({
  order_id: `223e4567-e89b-42d3-a456-${String(index).padStart(12, "0")}`,
}));

for (const scenario of [
  { name: "customer matches", broadUrl: "/rest/v1/customers", broadRows: customers },
  { name: "item-description matches", broadUrl: "/rest/v1/order_items", broadRows: items },
]) {
  test(`Orders search reports too-broad ${scenario.name} instead of silently truncating results`, async () => {
    const originalFetch = globalThis.fetch;
    const requested: string[] = [];
    globalThis.fetch = async (input) => {
      const url = String(input);
      requested.push(url);
      if (url.includes(scenario.broadUrl)) {
        return new Response(JSON.stringify(scenario.broadRows), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (url.includes("/rest/v1/customers")) {
        return new Response("[]", { status: 200, headers: { "Content-Type": "application/json" } });
      }
      if (url.includes("/rest/v1/order_items")) {
        return new Response("[]", { status: 200, headers: { "Content-Type": "application/json" } });
      }
      throw new Error("Orders query should not run when the match set exceeds the supported cap");
    };

    try {
      const response = await worker.fetch(
        new Request("https://worker.test/api/orders?search=needle", {
          headers: { Authorization: "Bearer synthetic-test-token" },
        }),
        env,
      );
      assert.equal(response.status, 422);
      assert.deepEqual(await response.json(), {
        error: "search_too_broad",
        message: "Narrow your search to reduce matching records",
      });
      assert.equal(requested.length, 2);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}
