# P3-T072 Completion — Implement grants and privileged access controls

Date: 2026-09-12

## Result
PASS — least-privilege grants and privileged access controls were implemented and verified against staging project `mijbpvgxrxjaalimyqgm`.

## Controls
- `anon` and `authenticated` have no direct table mutation privileges.
- `authenticated` retains SELECT on the application tables required by the RLS read model.
- `anon` and `authenticated` have no sequence privileges.
- `anon` has no EXECUTE privilege on application functions.
- `authenticated` has EXECUTE only on the approved command surface plus `app_role()`.
- Direct browser writes remain denied; state-changing operations use transactional SECURITY DEFINER commands.

## Staging verification
- anonymous INSERT on `orders`: denied
- authenticated INSERT on `orders`: denied
- authenticated SELECT on `orders`: allowed
- authenticated UPDATE on `financial_adjustments`: denied
- authenticated USAGE on `order_number_seq`: denied
- anonymous EXECUTE on `create_order(...)`: denied
- authenticated EXECUTE on `create_order(...)`: allowed

## Evidence
Migration: `supabase/migrations/20260912153000_grants_privileged_access_hardening.sql`
Test: `supabase/tests/database/023_grants_privileged_access.sql`

TCR: `ECO-TCR-P3-T072-20260912-8fff5c5a`
