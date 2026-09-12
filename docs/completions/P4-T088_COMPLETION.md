# P4-T088 — Test inactive-account access

**Status:** Complete  
**Completion date:** 2026-09-12  
**Task Completion Reference:** `ECO-TCR-P4-T088-20260912-935247a5`

## Scope

Verified the inactive application-profile access boundary without changing the locked business permission model.

## Implementation and verification

- Added `supabase/tests/database/036_inactive_account_access.sql` with 10 regression assertions covering the mandatory/default `profiles.active` field, active-profile role resolution, protected command boundaries, direct browser write denial, and Admin profile visibility policy.
- Added `tests/unit/auth_access.test.mjs` covering active versus inactive approved roles, inactive Admin denial, and unsupported/missing profile access behavior.
- Corrected `src/lib/auth.ts` relative module imports to explicit `.ts` paths so Node 24 unit execution can load the shared role module directly; this is test/runtime compatibility only and does not change authorization semantics.
- Updated `.github/workflows/ci.yml` so CI runs the inactive-account database regression test alongside fresh local Supabase rebuild verification.

## Acceptance evidence

GitHub Actions run **401 / 34708352101** passed:

- application lint
- TypeScript typecheck
- unit tests
- application build
- fresh local Supabase startup
- `supabase db reset` from the migration chain
- rebuild verification
- dedicated inactive-account access test

The broader legacy pgTAP suite is not claimed green; unrelated legacy failures remain outside this task's scope.

## Security boundary

An inactive application profile is not treated as operationally authorized. The existing authentication profile-loading path rejects inactive profiles, and the existing database role-resolution/command authorization remains the authoritative enforcement boundary. No production changes, Auth-admin API usage, direct browser table writes, or new business permissions were introduced.

## Commit / fingerprint

Primary T088 verification commit: `935247a5f812d89dd476833a8eacac7e2bec2ab0`.
