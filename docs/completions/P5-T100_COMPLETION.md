# P5-T100 — Implement Order Timeline Events

**Status:** Complete  
**Completion date:** 2026-09-13  
**Branch:** `feature/t099-order-item-lock`

## Scope

Expose the authoritative order event history as a read-only order timeline in the Operations application.

## Implementation

- Added an authenticated Worker GET endpoint for an order's timeline.
- Added the typed `getOrderTimeline` client command and `OrderTimelineEvent` contract.
- Added a Timeline action to the Orders Workspace.
- Timeline presentation is newest-first and shows event time, event type, parcel reference when present, and notes.
- Timeline reads the existing `public.order_events` source of truth; no event mutation path was introduced.
- Existing database event emitters remain authoritative for `OrderCreated`, `OrderUpdated`, `OrderConfirmed`, and `OrderCancelled`.
- Added database regression test `supabase/tests/database/047_order_timeline_events.sql` and included it in CI.

## Verification

GitHub Actions run **#505 / 34722301545** passed on commit `688f269a3d5a6e22e11495de9c7a73bd582e2dec`.

### Application quality

- Lint: passed
- Typecheck: passed
- Unit tests: passed — 28 tests
- Production build: passed

### Database verification

- Fresh isolated local Supabase project started successfully.
- Database reset from repository migrations and seed completed successfully.
- Database suite: **13 files / 146 tests — PASS**.
- `047_order_timeline_events.sql`: **11 assertions — PASS**.
- Rebuild verification and all preceding customer/order regression tests passed.

## Safety / Data Boundary

- Timeline access is authenticated and read-only.
- `order_events` remains protected by its existing immutability trigger.
- No production data was changed.

## Evidence

- Worker timeline endpoint: `worker/index.ts`
- Typed timeline client: `src/lib/commands.ts`
- Orders Workspace timeline UI: `src/components/OrdersWorkspace.tsx`
- Database regression test: `supabase/tests/database/047_order_timeline_events.sql`
- CI workflow coverage: `.github/workflows/ci.yml`
- Verified implementation head: `688f269a3d5a6e22e11495de9c7a73bd582e2dec`
- CI run: `505 / 34722301545`
