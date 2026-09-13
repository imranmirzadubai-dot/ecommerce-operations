# P3-T067 Completion — Implement PostgreSQL sequences/identifier generation

**Status:** PASS  
**Date:** 2026-09-12  
**TCR:** `ECO-TCR-P3-T067-20260912-1b1044f5`

## Scope

Verified and hardened PostgreSQL sequence-backed identifier generation for customer, order, and parcel identifiers.

## Implementation

- `public.customer_code_seq` exists and is non-cycling.
- `public.order_number_seq` exists and is non-cycling.
- `public.parcel_number_seq` exists and is non-cycling.
- `customers.customer_code` uses `CUS-` plus the customer sequence.
- `orders.order_number` uses `ORD-` plus the order sequence.
- `parcels.parcel_number` uses `PCL-` plus the parcel sequence.
- Direct sequence privileges were revoked from `anon` and `authenticated` to prevent browser-side sequence consumption.

## Staging Verification

Applied `20260912130000_identifier_sequences_hardening` to staging project `mijbpvgxrxjaalimyqgm` successfully.

Direct SQL verification confirmed:

- All three sequences exist: PASS
- Identifier column defaults remain sequence-backed: PASS
- `anon` sequence USAGE denied: PASS
- `authenticated` sequence USAGE denied: PASS

The repository test `supabase/tests/database/019_identifier_sequences.sql` was added for repeatable schema/privilege coverage. It is not claimed as executed via pgTAP because the staging environment does not provide the required pgTAP runner.

## Production

No production changes made.

## Evidence

- `supabase/migrations/20260912130000_identifier_sequences_hardening.sql`
- `supabase/tests/database/019_identifier_sequences.sql`
- staging migration application and direct SQL verification

## Completion Reference

`ECO-TCR-P3-T067-20260912-1b1044f5`
