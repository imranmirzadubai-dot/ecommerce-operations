# P7-T114 — Parcel Number Generation

## Status
Complete.

## Verification
Parcel number generation is now explicitly verified across the database model and `create_parcel` command:
- `parcel_number_seq` exists and is non-cycling;
- browser roles cannot directly use the sequence;
- the `parcels.parcel_number` column is sequence-backed;
- `create_parcel` consumes the same authoritative sequence;
- generated identifiers use the `PCL-XXXXXX` format;
- the target column is unique;
- source-order locking is retained before parcel mutation.

## Evidence
- Verification test commit: `8e6a7f43a264eb098a159603d9313ec29d71535`
- GitHub Actions CI: `#587` / run `34729478698` — PASS
- Local Supabase database reset/rebuild verification — PASS
- Database tests — PASS
- Lint — PASS
- Typecheck — PASS
- Unit tests — PASS
- Build — PASS

## Scope note
This task hardens and verifies the parcel-number generation contract established by T113. Barcode equality is tracked separately under P7-T115. No production data was used or modified.

## TCR
`ECO-TCR-P7-T114-20260913-8e6a7f43`
