# P4-T083 Completion Record

## Task
**P4-T083 — Implement admin user controls**

## Status
Complete

## Completion date
2026-09-12

## Implementation
- Added an Admin-only RLS SELECT policy for `public.profiles`, allowing administrators to inspect application profiles while preserving the existing self-only visibility for normal authenticated users.
- Added the `AdminUserControls` workspace component, visible only to an active Admin profile.
- Added controlled UI actions to link an existing Supabase Auth identity to an application profile using the existing `create_profile` command and to activate/deactivate profiles using the existing `set_profile_active` command.
- Added an Admin Users navigation entry that scrolls to the controlled user-management surface.
- No service-role credential, Auth-admin API, or direct browser table write was introduced.

## Tests / verification
- Added `supabase/tests/database/031_admin_user_controls.sql` covering the Admin profile policy, direct-table write denial, and least-privilege command execution boundaries.
- Updated `supabase/tests/database/028_database_rebuild_verification.sql` for the 33-migration chain and Admin profile SELECT policy.
- Updated `supabase/tests/database/028_rebuild_smoke.sql` for the additional Admin profile SELECT policy.
- GitHub Actions run **378 / 34680054537** passed:
  - application lint
  - typecheck
  - unit tests
  - production build
  - fresh local Supabase startup
  - `supabase db reset`
  - rebuild verification
  - rebuild smoke test
  - dedicated T082 lifecycle test
- The broader legacy pgTAP suite is not claimed green; unrelated pre-existing failures remain outside this task's scope.

## Security / scope boundary
- Admin profile visibility is explicitly restricted to `public.app_role() = 'admin'`.
- Browser roles retain no direct INSERT/UPDATE/DELETE privilege on `public.profiles`.
- User-changing operations continue through SECURITY DEFINER command boundaries rather than direct table mutation.
- Supabase Auth identities are not deleted or administered with server-only credentials by this task.
- T084 remains responsible for the broader authorization checks for protected commands.

## Task Completion Reference
`ECO-TCR-P4-T083-20260912-67bd02cb`
