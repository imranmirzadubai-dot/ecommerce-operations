# P5-T097 — Implement Order Confirmation

## Status

**Complete**

## Scope delivered

- Added a protected transactional `public.confirm_order(uuid, text)` command for the Draft → Confirmed lifecycle transition.
- Removed the legacy UUID-only confirmation overload so confirmation cannot bypass the idempotency boundary.
- Enforced authenticated operational roles (`sales`, `operations`, `admin`).
- Required an idempotency key and used the shared command idempotency contract.
- Locked the target order during confirmation and rejected every state other than `Draft`.
- Validated customer presence, nonnegative `original_amount`, at least one order item, and valid item descriptions/positive integer quantities before transition.
- Emitted `OrderConfirmed` and wrote an audit record in the same transaction.
- Added the authenticated-only confirmation client command and Draft-only UI action; confirmed orders are shown as locked.
- Added database and unit coverage and wired the database test into CI.
- Updated rebuild verification for the expanded migration chain.

## Verification

Final verified GitHub Actions run:

- **Run:** 460
- **Run ID:** 34718016086
- **Head commit:** `fc14b550839619611c941f87e85269c2234a137f`
- **Quality job:** PASS — lint, typecheck, unit tests, build
- **Database job:** PASS — migration reset and database regression suite
- **Database suite:** **115 tests across 10 files, all passing**

The first CI pass for the newly wired T097 database test exposed only a test-plan count mismatch (14 planned vs 15 executed). The test plan was corrected, then run 460 passed cleanly.

## Key files

- `supabase/migrations/20260913100000_order_confirmation.sql`
- `supabase/tests/database/044_order_confirmation.sql`
- `src/lib/commands.ts`
- `src/components/OrdersWorkspace.tsx`
- `tests/unit/order_confirmation.test.mjs`
- `.github/workflows/ci.yml`
- `supabase/tests/database/028_database_rebuild_verification.sql`

## Data safety

No production business data was modified. CI used an isolated local Supabase database rebuilt from the repository migrations and seed data.

## Next task

**P5-T098 — Lock `original_amount` after confirmation.**
