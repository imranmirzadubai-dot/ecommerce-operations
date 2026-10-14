# AUD-P2-003 — Isolated date-filter test harness feasibility

**Status:** Feasibility assessed; full Worker-level test still pending  
**Scope:** Read-only assessment and synthetic local reproduction only  
**Safety boundary:** No application code, tests, runtime configuration, secrets, or database state changed. No staging/production requests or database connections were made.

## Finding

The repository's `package.json` uses Node's built-in test runner:

```json
"test": "node --test tests/unit/*.test.js tests/unit/*.test.mjs"
```

There is no root `vitest.config.ts` or `playwright.config.ts` on the default branch. Existing unit tests are plain `.js`/`.mjs` files, so a deterministic synthetic regression test can fit the current test convention. However, a test that merely copies the faulty query-building logic would prove JavaScript semantics, not that the deployed Worker path is wired correctly.

## Local reproduction performed

Runtime: Node.js v22.16.0 in an isolated local shell.

Synthetic records:

| ID | order_date |
|---|---|
| before | 2026-01-05 |
| inside | 2026-01-15 |
| after | 2026-01-25 |

The source pattern performs two calls with the same key:

```js
params.set("order_date", "gte.2026-01-10");
params.set("order_date", "lte.2026-01-20");
```

Observed query: `order_date=lte.2026-01-20`.

Observed current-behavior synthetic matches: `before`, `inside`.  
Expected matches for the inclusive range: `inside` only.

The local assertions passed and reproduced the overwrite semantics. This is **not** a Worker/API integration test and does not access or represent real order data.

## Recommended safe next test layer

1. Add a focused regression test using the existing `node:test` convention.
2. Prefer exercising the actual Worker handler or a query-builder function imported from production source; avoid duplicating the defect logic inside the test.
3. Stub/mock outbound `fetch` and use synthetic response rows only.
4. Assert the upstream query carries both inclusive bounds and the result excludes records outside either bound.
5. Cover lower-only, upper-only, same-day, boundary, reversed, malformed and impossible dates from AUD-P2-002.
6. Run the test and existing unit suite locally or in CI with no production/staging credentials. Do not run migrations or reset any database.

## Feasibility and limitation

A local-only test is feasible. The current test script supports adding a plain Node test, but the cleanest source-faithful approach depends on whether the Worker entrypoint can be imported in the repository's Node test environment without bundling or platform-specific globals. If not, introduce no runtime refactor as part of this audit; document the blocker and propose a minimal test seam separately for approval.

## Decision boundary

This document proposes a test approach only. It does not fix the date-filter defect, add tests, change code/configuration, call the live Worker, or connect to any database. PRs #342 and #343 remain separate, draft and unmerged.
