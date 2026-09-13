# P7-T119 — Pre-Dispatch Allocation Correction

## Status
Implementation complete; CI verification pending/required before merge.

## Contract
`public.correct_parcel_allocation(parcel_item_id, corrected_quantity, idempotency_key)` provides the explicit pre-dispatch correction path defined by the master implementation plan.

- Requires an authenticated `operations` or `admin` actor.
- Requires the target allocation to be active and its parcel to be `Prepared`.
- Rejects negative corrected quantities.
- Locks the allocation, parcel, and order item before mutation.
- Revalidates the ordered-quantity invariant against all other active allocations.
- Never deletes or rewrites the original allocation quantity.
- Marks the original allocation `Reversed` and appends a replacement `Allocated` row when the corrected quantity is non-zero.
- A zero correction releases the allocation while retaining the original row/history.
- Emits a permanent `ParcelAllocationCorrected` order event and an audit record.
- Uses the shared command idempotency contract.
- Browser execution is restricted to the authenticated role.

## Files
- `supabase/migrations/20260913160000_correct_parcel_allocation.sql`
- `supabase/tests/database/056_pre_dispatch_allocation_correction.sql`
- `src/lib/parcelCommands.ts`
- `.github/workflows/ci.yml`

## Verification
CI must run the complete existing database suite plus test 056 and the quality job. No production data is touched.
