# P3-T066 Completion — Implement import_batches and import_rows

**Status:** PASS
**Date:** 2026-09-12
**TCR:** ECO-TCR-P3-T066-20260912-2c5e5195

## Scope

Implemented/hardened the existing `import_batches` and `import_rows` foundation without changing production.

## Changes

- Added an explicit allowed-status constraint for `import_rows`:
  `Pending`, `Valid`, `Invalid`, `Imported`, `Skipped`, `Failed`.
- Added operational indexes for batch status, batch initiator, and row status.
- Preserved RLS on both tables.
- Preserved admin-only authenticated SELECT policies.
- Revoked direct browser writes from `anon` and `authenticated`.
- Granted authenticated SELECT only.

## Staging Verification

Applied migration `20260912124500_import_batches_rows_hardening` to staging project `mijbpvgxrxjaalimyqgm` successfully.

Direct SQL privilege verification confirmed:

- authenticated SELECT on `import_batches`: PASS
- authenticated INSERT on `import_batches`: DENIED
- authenticated SELECT on `import_rows`: PASS
- authenticated UPDATE on `import_rows`: DENIED

RLS remained enabled on both tables, and the admin-only policies remained present.

The repository test `supabase/tests/database/018_import_batches_rows_hardening.sql` was added. It is not claimed as executed via pgTAP because the staging environment does not provide the required pgTAP runner.

## Production

No production changes made.

## Evidence

- `supabase/migrations/20260912124500_import_batches_rows_hardening.sql`
- `supabase/tests/database/018_import_batches_rows_hardening.sql`
- staging migration application and direct SQL catalog/privilege verification

## Completion Reference

`ECO-TCR-P3-T066-20260912-2c5e5195`
