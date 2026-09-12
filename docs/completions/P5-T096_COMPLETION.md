# P5-T096 — Pre-confirmation Order Editing — COMPLETE

## Outcome
Draft Orders can be edited before confirmation through the authoritative `update_order` transactional command.

## Implemented
- Added `public.update_order(...)` as an idempotent, SECURITY DEFINER command.
- Restricted the command to authenticated `sales`, `operations`, and `admin` roles.
- Restricted edits to orders whose lifecycle state is `Draft`.
- Validated customer name, phone, non-negative Total Order Amount, and at least one valid item.
- Preserved the existing AED `NUMERIC(12,2)` amount contract.
- Updated editable customer/order fields and replaced the Draft order-item set atomically.
- Emitted `OrderUpdated` and wrote an audit record in the same transaction.
- Added the command to the browser-facing TypeScript command client.
- Extended the Orders workspace to expose an Edit action for Draft orders and a complete Draft editor for customer details, amount, notes, and items.
- Extended the Worker order read to return the fields required by the Draft editor.
- Added database and UI regression coverage.
- Added the new database test to CI.
- Hardened execute privileges so `anon` cannot execute `update_order`.

## Verification
Final GitHub Actions run: `34716830485` / run `448` on branch `feature/t096-pre-confirmation-order-editing`.

Quality job: PASS
- Lint
- Typecheck
- Unit tests
- Build

Database job: PASS
- Local Supabase startup
- Full migration reset
- Rebuild verification
- Existing customer/order regression tests
- Manual Total Order Amount regression tests
- New P5-T096 Draft Order editing contract tests

The final database run passed all 100 tests across 9 test files.

## Migration
`supabase/migrations/20260913090000_pre_confirmation_order_editing.sql`

## Tests
`supabase/tests/database/043_pre_confirmation_order_editing.sql`
`tests/unit/pre_confirmation_order_editing.test.mjs`

## Final commit
`9da598b43bf46a16a39fe2222734dbcc9f95eb66`

## Next task
P5-T097 — Confirm Draft Order lifecycle transition.
