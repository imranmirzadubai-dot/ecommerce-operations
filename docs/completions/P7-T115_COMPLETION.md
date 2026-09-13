# P7-T115 — Barcode Equals Parcel Number

## Status
Complete.

## Verification
The parcel barcode contract is explicitly verified:
- barcode is mandatory;
- the `parcels` table has a database check constraint enforcing `barcode = parcel_number`;
- barcode is uniquely indexed;
- `create_parcel` derives the barcode from the generated parcel number;
- returned/idempotent command results preserve that equality.

## Evidence
- Verification test commit: `ac1f4086399c67160e600cd7c26bd144d57c1257`
- GitHub Actions CI: `#589` / run `34729607826` — PASS
- Local Supabase database reset/rebuild verification — PASS
- Database tests — PASS
- Lint — PASS
- Typecheck — PASS
- Unit tests — PASS
- Build — PASS

## Scope note
Barcode rendering/Code 128 hardware validation remains a later P8 task. This milestone establishes the authoritative database equality contract. No production data was used or modified.

## TCR
`ECO-TCR-P7-T115-20260913-ac1f4086`
