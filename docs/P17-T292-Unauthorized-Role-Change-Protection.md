# P17-T292 — Prevent Unauthorized Role Changes

## Scope

Add a database-level defense-in-depth control ensuring authenticated non-Admin users cannot change `profiles.role` through any direct or future mutation path.

## Contract

- Role changes remain an Admin-only operation.
- T287 remains the primary trusted command boundary for intentional role changes.
- This trigger rejects role changes when an authenticated actor is not currently authorized as Admin.
- `auth.uid()` is evaluated at execution time; authorization is not based on client-supplied role data.
- Internal/server-side operations with no authenticated actor (`auth.uid() IS NULL`) are not blocked by this trigger; their trusted server boundaries remain responsible for authorization.
- The trigger uses `SECURITY DEFINER` with a pinned `search_path` and exposes no service-role credentials.
- Existing RLS policies are not weakened or replaced.
- T291 separately prevents users from changing their own role or active status.
- T293 remains responsible for final-active-Admin protection.

## Separation of concerns

- T287 authorizes the supported Admin role-change command.
- T291 prevents self-escalation as a database-level invariant.
- T292 prevents authenticated non-Admins from changing another profile's role through an alternate mutation path.
- T293 protects the last active Admin invariant.

## Production safety

No production database mutation is part of T292 implementation. Migration deployment and production verification remain later P17 tasks.
