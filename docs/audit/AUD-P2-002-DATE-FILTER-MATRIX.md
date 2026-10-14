# AUD-P2-002 — Orders date-filter validation matrix

## Status
Test design documented from static source review. Tests have not been implemented or executed. No code changes, API requests, database access, or deployment actions were performed.

## Source behavior reviewed
`worker/index.ts` validates date strings using a `YYYY-MM-DD` regex and `Date.parse(value + 'T00:00:00Z')`, rejects `date_from > date_to`, and then attempts to apply both bounds with `URLSearchParams.set("order_date", ...)`. As documented in AUD-P2-001, the second set replaces the first, so the combined-bound case is defective at source level.

## Test matrix
All data should be synthetic and isolated. Expected behavior below defines the intended contract, not a claim that current code passes.

| Case | Input | Expected result |
|---|---|---|
| No date bounds | neither parameter | No date predicate |
| Lower bound only | `date_from=2026-01-10` | Include dates on/after 10 Jan |
| Upper bound only | `date_to=2026-01-20` | Include dates on/before 20 Jan |
| Both bounds | 10 Jan through 20 Jan | Include only dates in the inclusive range |
| Same-day range | both bounds `2026-01-15` | Include only 15 Jan |
| Exact lower boundary | record on 10 Jan | Include |
| Exact upper boundary | record on 20 Jan | Include |
| One day before range | record on 9 Jan | Exclude |
| One day after range | record on 21 Jan | Exclude |
| Reversed range | from 20 Jan, to 10 Jan | HTTP 400 `invalid_date_range` |
| Invalid calendar date | `2026-02-30` | HTTP 400 `invalid_date_range` |
| Wrong format | `10-01-2026` | HTTP 400 `invalid_date_range` |
| Leap-day valid | `2024-02-29` | Accept as valid date |
| Leap-day invalid | `2025-02-29` | Reject as invalid date |
| Empty parameter | `date_from=` | Confirm contract; current source treats empty string as supplied and validation rejects it |
| Timezone/database type | synthetic dates at boundaries | Confirm `order_date` is date-valued and inclusive behavior remains correct in the actual query contract |

## Acceptance criteria
1. Tests run in an isolated Worker/unit or local integration harness; no staging or production endpoint.
2. Both-bound test fails against the current implementation before any fix.
3. Each validation case asserts status/error contract and resulting rows or query predicates.
4. Test uses no real customer/order data and does not require remote database credentials.
5. Record command, output, and commit SHA in the tracker after execution.

## Boundary
This document defines the test matrix only. It does not implement tests or a fix. No PR merge is authorized and no database/schema/data/deployment changes are permitted by this review.
