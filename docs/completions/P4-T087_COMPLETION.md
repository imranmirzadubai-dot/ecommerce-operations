# P4-T087 — Admin Permissions Completion

**Task:** P4-T087 — Test Admin permissions  
**Phase:** 4 — Auth & Administration  
**Gate:** Access Gate  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P4-T087-20260912-577846bd`

## Outcome

Added a dedicated Admin-permission regression suite confirming that the existing administrative controls are restricted to the Admin application role while Admin retains access to the shared protected operational command boundary.

The suite verifies:

- `create_profile` requires the Admin application role.
- `set_profile_active` requires the Admin application role.
- Anonymous callers cannot execute either administrative command.
- Admin profile visibility is protected by the dedicated `profiles_admin_select` policy.
- Authenticated browser roles retain no direct table-write privilege.
- Admin remains included in the shared protected operational command boundary.

No new business permission was invented in T087. The test exercises the authorization model already implemented in T080–T084.

## Evidence

- Dedicated test: `supabase/tests/database/035_admin_permissions.sql`
- Test implementation commit: `577846bd54b501e4a1d39b3adb5be43d722eb4fb`
- CI workflow updated to execute the dedicated Admin test.
- T087 CI verification must pass before this milestone is closed.

## Scope boundary

T087 is a permission regression test milestone. It does not alter production configuration or data and does not introduce direct browser writes or Auth-admin APIs. The broader legacy pgTAP suite remains outside this milestone and is not claimed green.
