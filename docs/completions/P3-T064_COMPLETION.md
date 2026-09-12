# P3-T064 Completion — Implement order_events

**Status:** PASS  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P3-T064-20260912-b76d281c`

## Scope
Harden `public.order_events` as append-only operational history with controlled authenticated read access.

## Implementation
- Added `prevent_order_event_mutation()` SECURITY DEFINER trigger guard.
- UPDATE and DELETE are rejected; corrections are represented by new events.
- Preserved existing order, optional parcel, and actor foreign keys.
- Enabled RLS and revoked direct authenticated writes.
- Granted authenticated SELECT, subject to the existing role-aware SELECT policy.

## Verification — staging
Project: `mijbpvgxrxjaalimyqgm`

- immutable trigger: PASS
- RLS enabled: PASS
- authenticated SELECT policy: PASS
- authenticated SELECT grant: PASS
- authenticated INSERT grant: DENIED
- authenticated UPDATE grant: DENIED
- authenticated DELETE grant: DENIED

No production changes were made.

## Evidence
- `supabase/migrations/20260912121500_order_events_immutable.sql`
- `supabase/tests/database/016_order_events_immutable.sql`
