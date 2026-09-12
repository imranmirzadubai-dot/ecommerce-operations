# P3-T062 Completion — Implement financial_adjustments append-only ledger

## Result
PASS — database hardening and staging verification completed on 2026-09-12.

## Implementation
- Migration: `supabase/migrations/20260912114500_financial_adjustments_append_only.sql`
- Repository verification test: `supabase/tests/database/014_financial_adjustments_append_only.sql`
- Financial adjustment mutation guard blocks UPDATE and DELETE.
- `delta_amount` is constrained to two-decimal precision.
- RLS is enabled.
- Authenticated access is SELECT-only; direct writes are denied.

## Staging verification
- Precision constraint: PASS
- Immutable trigger: PASS
- RLS: PASS
- Authenticated SELECT: PASS
- Authenticated INSERT: DENIED
- Authenticated UPDATE: DENIED
- Authenticated DELETE: DENIED

The repository test was added for fixture-enabled execution; no pgTAP/test-runner result is claimed here.

## Production
No production changes were made.

## TCR
`ECO-TCR-P3-T062-20260912-cb69ae61`
