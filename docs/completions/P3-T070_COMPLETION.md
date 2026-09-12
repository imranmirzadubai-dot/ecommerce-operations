# P3-T070 Completion — Implement transactional business functions/commands

**Status:** PASS
**Date:** 2026-09-12
**TCR:** ECO-TCR-P3-T070-20260912-1421b394

## Scope

Completed the transactional command layer reconciliation and access hardening for the database foundation.

## Canonical Commands

Verified and retained the idempotent transactional command surface:

- `create_order(..., p_idempotency_key text)`
- `confirm_order(p_order_id uuid, p_idempotency_key text)`
- `cancel_order(p_order_id uuid, p_idempotency_key text)`
- `cancel_parcel(p_parcel_id uuid, p_idempotency_key text)`
- `resolve_customer_by_phone(p_phone text)`
- `claim_command_idempotency(...)`
- `complete_command_idempotency(...)`

Legacy non-idempotent order/confirmation/cancellation overloads were removed so callers cannot bypass the command contract.

## Security

All seven command/helper functions are `SECURITY DEFINER`, use controlled `search_path = pg_catalog, public`, and are executable by `authenticated` only. Direct `anon` execution is denied.

## Staging Verification

Applied the hardening migrations to staging project `mijbpvgxrxjaalimyqgm` and verified directly through PostgreSQL catalog privileges:

- 7 canonical command/helper functions present: PASS
- 7 functions are SECURITY DEFINER: PASS
- authenticated EXECUTE: PASS
- anon EXECUTE: DENIED
- legacy non-idempotent overloads absent: PASS
- `cancel_parcel` canonical idempotent command present: PASS

Repository test: `supabase/tests/database/021_transactional_commands_access.sql`.

The test is not claimed as executed through pgTAP because the staging environment does not provide the required pgTAP runner.

## Production

No production changes made.

## Evidence

- `supabase/migrations/20260912150000_transactional_command_access_hardening.sql`
- `supabase/tests/database/021_transactional_commands_access.sql`
- existing transactional/idempotency migrations
- staging catalog and privilege verification

## Completion Reference

`ECO-TCR-P3-T070-20260912-1421b394`
