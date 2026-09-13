# P3-T061 Completion — COD receipts with UNIQUE(parcel_id)

**Status:** PASS  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P3-T061-20260912-cb533767`

## Scope

Implement and verify the P3-T061 requirement that COD receipts are unique per parcel.

## Implementation

- Migration: `supabase/migrations/20260912113000_cod_receipts_parcel_uniqueness.sql`
- Repository test: `supabase/tests/database/013_cod_receipts_parcel_uniqueness.sql`
- The migration creates a unique index on `public.cod_receipts(parcel_id)` using `IF NOT EXISTS` so the existing foundation constraint is safely reconciled.
- RLS remains enabled and authenticated browser access remains SELECT-only.

## Staging verification

Staging project: `mijbpvgxrxjaalimyqgm`

Direct SQL verification passed:

- unique index present: `true`
- RLS enabled: `true`
- authenticated SELECT: `true`
- authenticated INSERT: `false`
- authenticated UPDATE: `false`
- authenticated DELETE: `false`

The repository test is supplied for fixture-enabled execution. No pgTAP pass is claimed because the staging environment does not provide the required pgTAP runner.

## Production safety

No production changes were made.
