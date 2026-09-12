# P3-T073 Completion

## Task
Implement security-definer functions where required with controlled `search_path`.

## Result
PASS — application SECURITY DEFINER functions were hardened with `search_path = pg_catalog, public`.

## Scope
- `app_role()`
- `create_order(...)`
- `confirm_order(...)`
- `cancel_order(...)`
- `cancel_parcel(...)`
- `claim_command_idempotency(...)`
- `complete_command_idempotency(...)`
- `resolve_customer_by_phone(...)`

## Verification
The companion SQL test inspects `pg_proc.prosecdef` and `proconfig` for the approved function set. The staging database was updated with the migration and verified directly through the PostgreSQL catalog.

## Migration
`supabase/migrations/20260912154500_security_definer_search_path_hardening.sql`

## Test
`supabase/tests/database/024_security_definer_search_path.sql`

## Completion date
2026-09-12
