# P5-T094 — Implement order item entry (description + integer quantity)

- **Task:** P5-T094 — Implement order item entry (description + integer quantity)
- **Phase:** 5 — Customer & Order Core
- **Milestone / Gate:** Commercial Gate
- **Status:** Complete
- **Completion date:** 2026-09-12
- **TCR:** ECO-TCR-P5-T094-20260912-e8b42967

## Implementation

The Draft Order workflow already contains the required Order Item entry behavior established with the canonical order-creation command. T094 adds dedicated regression coverage so the contract is explicitly verified and remains protected.

### Application entry

- The Operations Dashboard maintains an `OrderItem` row model with `description` and `quantity` fields.
- Operators can add multiple item rows and remove rows while retaining at least one row.
- Each item exposes a Product description field and a Quantity field.
- Quantity is presented as a numeric input with `min=1` and `step=1`.
- Submission validates every item for a non-empty description and positive whole quantity before calling the server command.

### Authoritative database contract

The canonical `create_order` command:

- Iterates over every supplied item row.
- Trims and requires a non-empty description.
- Requires quantity text to contain digits only.
- Casts quantity to PostgreSQL `INTEGER`.
- Rejects zero or negative quantities.
- Assigns deterministic 1-based line numbers.
- Persists only `description` and integer `quantity` into `public.order_items`.
- Returns an explicit line-specific validation error for invalid item input.

The `public.order_items.quantity` column is also verified as PostgreSQL `INTEGER`.

## Verification

Dedicated coverage was added at:

- `supabase/tests/database/041_order_item_entry.sql`
- `tests/unit/order_item_entry.test.mjs`

The CI workflow was extended to run the new database test after a fresh local Supabase reset.

GitHub Actions **run 426 / 34713889495** passed:

- lint
- typecheck
- unit tests
- build
- fresh local Supabase startup
- `supabase db reset`
- rebuild verification
- customer-resolution regression tests
- order-creation regression tests
- order-item-entry regression tests

The first T094 CI attempt (run 425 / 34713723772) exposed one overly specific test assertion. The implementation itself and all pre-existing checks passed; the assertion was corrected without changing application or database behavior. Run 426 then passed all checks.

The broader legacy pgTAP suite remains outside this task's acceptance scope and is not claimed green.

## Scope / security boundary

No new business rule or permission was invented. Order item entry remains part of the authenticated Draft Order workflow and is enforced by the existing transactional `create_order` command boundary. No production environment was changed.

## Task Completion Reference

`ECO-TCR-P5-T094-20260912-e8b42967`
