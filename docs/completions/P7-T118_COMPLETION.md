# P7-T118 — Split Allocation Across Parcels

## Status
Implementation complete on the feature branch; awaiting PR merge to `main` before the milestone is marked shipped.

## Implemented
- Added `public.allocate_parcel_items(order_item_id, allocations, idempotency_key)` as an atomic split-allocation command.
- Accepts a JSON allocation list containing at least two distinct parcels and positive integer quantities.
- Locks the order item and target parcels in deterministic order before checking remaining allocation capacity.
- Rejects cross-order parcels, terminal/cancelled parcels, duplicate target parcels, invalid quantities, and total allocation above ordered quantity.
- Inserts one `parcel_items` row per target parcel and records immutable order events plus audit records.
- Uses command idempotency so retries return the original allocation result.
- Added `allocateParcelItemsSplit` client wrapper using the existing worker `allocate_parcel_items` command allow-list.
- Added database contract coverage in test 055 and included it in CI.

## Verification
- Database test: `supabase/tests/database/055_split_parcel_allocation.sql`
- CI must pass the existing quality suite plus Local Supabase database suite, including test 055.
- No production data is touched.

## Acceptance mapping
- One order item can be allocated to multiple physical parcels without duplicating or overwriting order-item quantity.
- Allocation is transactional and preserves immutable allocation/event/audit history.
- Existing allocated quantity plus the new split cannot exceed ordered quantity.
- Browser access is restricted to authenticated users; domain authorization remains Operations/Admin.

## Evidence
- Feature branch: `feature/t118-split-allocation-across-parcels`
- Commit(s): recorded in the PR and final merge commit.
- PR: to be created after CI verification.
