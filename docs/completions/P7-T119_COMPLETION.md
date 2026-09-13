# P7-T119 — Pre-Dispatch Allocation Correction

## Scope
Implement the explicit `correct_parcel_allocation` command required by the master implementation plan for correcting an allocation while the parcel remains `Prepared`.

## Implementation
- Added `public.correct_parcel_allocation(uuid, integer, text)`.
- Requires authenticated `operations` or `admin` role.
- Accepts non-negative corrected quantities; zero releases the allocation.
- Locks the parcel item and parcel, then the order item before mutation.
- Requires the parcel to be `Prepared` and the allocation to be active.
- Rechecks the ordered-quantity invariant against all other active allocations.
- Never deletes or rewrites the original allocation quantity.
- Marks the original allocation `Reversed`; non-zero corrections append a replacement `Allocated` row.
- Emits `ParcelAllocationCorrected` event and audit history.
- Uses shared command idempotency.
- Grants execution only to `authenticated` and revokes `anon`/`public`.
- Added client wrapper and database contract test 056.
- Added test 056 to CI.

## Verification
The PR must pass the existing quality checks and full Local Supabase database suite, including test 056, before merge. No production data is touched.
