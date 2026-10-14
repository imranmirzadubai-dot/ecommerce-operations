# AUD-P2-001 — Orders date-range filter reproduction

## Status
Static defect reproduced from source inspection; runtime/integration test still pending. Documentation only. No code changes, requests, database access, or production actions.

## Evidence
In `worker/index.ts`, `handleOrders` applies both date bounds to the same `URLSearchParams` key:

```ts
if (dateFrom) query.set("order_date", `gte.${dateFrom}`);
if (dateTo) query.set("order_date", `lte.${dateTo}`);
```

`URLSearchParams.set()` replaces the existing value for a key. When both dates are supplied, the second call replaces the first rather than combining the predicates. Thus the constructed query cannot enforce both bounds; the `date_to` predicate overwrites `date_from`.

Source: `worker/index.ts` on main, `handleOrders` function.

## Synthetic reproduction case
Use isolated test fixtures only:

| Order | order_date | Expected for 2026-01-10 through 2026-01-20 |
|---|---|---|
| A | 2026-01-05 | Excluded |
| B | 2026-01-15 | Included |
| C | 2026-01-25 | Excluded |

With both bounds supplied, the currently constructed query contains only `order_date=lte.2026-01-20`. The lower bound is absent, so order A can incorrectly match. No actual API request or database query was sent for this review.

## Required next verification
1. Add a failing Worker/integration test using isolated synthetic fixtures for both bounds.
2. Add cases for `date_from` only, `date_to` only, equal bounds, invalid/reversed dates, and boundary dates.
3. Fix only after the test demonstrates the defect and a separately scoped change is authorized; preserve existing sort and pagination.
4. Run the targeted test and relevant suite, then record before/after evidence.

## Safety boundary
This finding is confirmed by source semantics, not by runtime execution. No code fix is proposed or included here. No production or staging database was accessed or changed. No PR is approved to merge by this document.
