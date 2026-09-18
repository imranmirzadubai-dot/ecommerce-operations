# P11-T184 Completion — Test unauthorized financial adjustment

## Scope
Add deterministic database regression coverage for unauthorized calls to the authoritative `create_financial_adjustment` command.

## Verification
- Confirms the authoritative command and expected signature exist.
- Confirms `SECURITY DEFINER` and controlled `search_path`.
- Confirms unauthenticated callers are rejected.
- Confirms non-admin roles are rejected by the command-level role guard.
- Confirms unauthorized attempts use SQLSTATE `42501` and the explicit Admin-only message.
- Confirms function execution privileges are revoked from `public` and `anon`, while `authenticated` retains entry-point execution subject to the Admin guard.
- Confirms the authorization guard occurs before the financial-adjustment insert.
- Confirms the authentication and Admin-role checks are combined at the command entry point.

## Test
`supabase/tests/database/104_unauthorized_financial_adjustment.sql` contains 10 pgTAP assertions.

## CI
`.github/workflows/t184-unauthorized-financial-adjustment.yml` runs a clean Supabase start/reset and executes the dedicated regression test.

## Data safety
No production business data was changed.
