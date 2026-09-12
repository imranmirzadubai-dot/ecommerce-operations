# P4-T082 Completion Record

## Task
**P4-T082 — Implement active/inactive account lifecycle**

## Status
Complete

## Completion date
2026-09-12

## Implementation
- Added `public.set_profile_active(uuid, boolean)` as the controlled application-profile lifecycle command.
- The command requires an authenticated caller with an active `admin` application role.
- It validates the target profile and requested status, updates only `profiles.active`, refreshes `updated_at`, and returns the resulting profile.
- The Supabase Auth identity is retained; this task controls the linked application profile lifecycle rather than deleting or disabling the Auth identity.
- Browser roles receive no direct table mutation privilege; the command is `SECURITY DEFINER` with `search_path = pg_catalog, public`, anonymous execution revoked, and authenticated execution granted.
- Existing application authentication already rejects inactive profiles during sign-in and session restoration, so deactivation removes operational access without inventing a separate Auth-user lifecycle.

## Tests / verification
- Added `supabase/tests/database/030_profile_active_lifecycle.sql` with structural/security assertions for command existence, SECURITY DEFINER, controlled search path, admin authorization, target validation, active-state update behavior, and profile-state constraints.
- Updated `supabase/tests/database/028_database_rebuild_verification.sql` for the 32-migration chain and the new lifecycle command.
- Updated CI to execute the dedicated T082 lifecycle test in addition to rebuild verification and smoke tests.
- CI verification run: pending after this test-harness correction.
- The broader legacy pgTAP suite is not claimed green; unrelated pre-existing failures remain outside T082 scope.

## Security / scope boundary
- No production database was changed.
- No Supabase Auth user deletion or password/account recovery behavior was invented.
- T083 remains responsible for administrator-facing user controls; T084 remains responsible for the broader command-authorization layer.

## Task Completion Reference
`ECO-TCR-P4-T082-20260912-d20b8a97`
