# P7-T113 — Parcel Creation

## Status
Complete.

## Implementation
Implemented the transactional `create_parcel` command and its authenticated client wrapper.

The command:
- requires an authenticated Operations or Admin role;
- validates the order exists and is not Cancelled or Completed;
- requires an idempotency key and uses the shared command-idempotency contract;
- generates the authoritative `PCL-XXXXXX` parcel number from `parcel_number_seq`;
- creates the parcel in `Prepared` state;
- sets `barcode` equal to `parcel_number`;
- appends an immutable `ParcelCreated` order event;
- writes the corresponding audit record;
- returns the created parcel identity and state.

## Evidence
- Implementation migration: `6da58fb3af47f3c10587ed8b901319a14acc240e`
- Client command: `cf512bf7b20543b31de4ff3d0214571029f7491f`
- Database test: `eb7e15ef184ae7684b2d636bd4ddb51d14f682ad`
- Rebuild verification harness fix: `f2b591848f2f9ae99214ef8a2dccce62120eef9f`
- GitHub Actions CI: `#585` / run `34729317655` — PASS
- Local Supabase database reset/rebuild verification — PASS
- Database tests — PASS
- Lint — PASS
- Typecheck — PASS
- Unit tests — PASS
- Build — PASS

## Scope note
Allocation is intentionally not part of T113; it is the subsequent P7-T116 task. No production data was used or modified.

## TCR
`ECO-TCR-P7-T113-20260913-f2b59184`
