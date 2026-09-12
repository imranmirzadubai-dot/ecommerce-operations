# P5-T095 — Implement manual Total Order Amount entry

- **Task:** P5-T095 — Implement manual Total Order Amount entry
- **Phase:** 5 — Customer & Order Core
- **Milestone / Gate:** Commercial Gate
- **Status:** Complete
- **Completion date:** 2026-09-12
- **TCR:** ECO-TCR-P5-T095-20260912-7026c3d3

## Implementation

The Draft Order workflow now has an explicit, validated manual Total Order Amount boundary aligned with the locked v4.0 financial contract.

### Application entry

- Sales enters one **Total Order Amount (AED)** for the order.
- The field is required, non-negative, decimal-oriented and limited to two decimal places in the UI.
- The application accepts decimal text rather than converting the commercial amount through browser floating-point arithmetic before the command boundary.
- Input is canonicalized to two decimal places before `create_order` is called.
- Values above the PostgreSQL `NUMERIC(12,2)` maximum are rejected before submission.
- The UI explicitly communicates that there are no item prices, VAT, discount or service-fee fields in the MVP.
- After successful Draft Order creation, the amount field is cleared with the rest of the new-order form.

### Authoritative database contract

The existing canonical `create_order` command remains authoritative:

- It accepts `p_original_amount` as PostgreSQL numeric input.
- It rejects a missing or negative amount.
- It persists the supplied value to `public.orders.original_amount`.
- The `orders.original_amount` column is verified as `NUMERIC(12,2)`.
- The amount is included in the creation audit payload.
- The command does not derive the order amount from item quantities or introduce excluded monetary fields.

The locked v4.0 rule remains unchanged: Sales manually enters one Total Order Amount; the stored original amount becomes immutable at order confirmation and later financial changes use the append-only adjustment ledger.

## Verification

Dedicated coverage was added at:

- `tests/unit/total_order_amount_entry.test.mjs`
- `supabase/tests/database/042_manual_total_order_amount.sql`

The CI workflow was extended to run the new database contract test after a fresh local Supabase reset.

GitHub Actions **run 436 / 34716085255** passed:

- lint
- typecheck
- unit tests
- build
- fresh local Supabase startup
- `supabase db reset`
- rebuild verification
- UAE phone normalization regression tests
- customer resolution regression tests
- order creation regression tests
- order item entry regression tests
- manual Total Order Amount database contract tests

The first T095 database verification run (run 435 / 34715951457) exposed one overly specific assertion about how PostgreSQL renders a numeric function argument. The underlying schema and command were correct; the assertion was changed to verify the actual PostgreSQL function argument type. Run 436 then passed all checks.

## Staging verification

A read-only staging schema verification confirmed:

- `orders.original_amount` is PostgreSQL `numeric` with precision 12 and scale 2.
- `create_order` exists with the expected numeric amount argument plus the established idempotency parameter.

No production data was created or modified by this task.

## Scope / security boundary

No new business rule or permission was invented. The task implements the already-locked v4.0 manual Total Order Amount contract inside the authenticated Draft Order workflow. State-changing creation continues to use the existing transactional command boundary; browser roles do not receive direct table-write access.

## Task Completion Reference

`ECO-TCR-P5-T095-20260912-7026c3d3`
