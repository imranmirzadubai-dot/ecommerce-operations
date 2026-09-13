# P6-T112 — Historical Orders Searchability Verification

## Status
Complete — capability verified; no historical business fixture is present in the deterministic seed.

## Verification
The normal Orders workspace defaults to **All dates** and sends empty `date_from` / `date_to` parameters. The Orders API applies an `order_date` range only when those parameters are explicitly supplied. Server-side search remains active independently of date filtering and searches order number, customer fields and item description.

This preserves the required architecture for historical orders: imported historical records are not implicitly excluded from the normal Orders view by a current-date filter.

## Evidence
- Verification test commit: `3e9a6b60a4227c1d03ee6469ce1e3553da27e79d`
- GitHub Actions CI: `#579` / run `34729048249` — PASS
- Local Supabase database reset/rebuild verification — PASS
- Lint — PASS
- Typecheck — PASS
- Unit tests — PASS
- Build — PASS
- Deterministic seed inspection: `supabase/seed.sql` intentionally contains no business rows, so no historical production-like record was fabricated for this verification.

## Scope note
This task verifies the normal-view search/date-filter behavior rather than importing or modifying business data. No production data was used or modified.

## TCR
`ECO-TCR-P6-T112-20260913-3e9a6b60`
