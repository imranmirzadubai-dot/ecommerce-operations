# P17-T288 — Admin Activate / Deactivate

## Purpose

Provide the trusted server-side lifecycle command for activating or deactivating another user's application profile.

## Contract

- Supabase Auth remains the identity/account system.
- `public.profiles.active` remains the authoritative application-access state.
- Only an authenticated active Admin may change another user's status.
- Self-status changes are prohibited.
- Only the `active` property is mutable by this command.
- The target profile is locked with `FOR UPDATE` before evaluation.
- The command uses the existing command-idempotency architecture.
- The final active Admin cannot be deactivated.
- Privileged before/after status changes are recorded in `audit_logs`.
- `SECURITY DEFINER` uses a pinned `search_path`.
- Function execution is restricted to `authenticated`.
- Existing RLS policies are not weakened.
- No hard delete or Auth-account deletion is performed.

## Access Enforcement

`public.app_role()` only returns a role when the authenticated user's profile is active. Existing authorization paths that depend on `app_role()` therefore treat an inactive profile as unauthorized without introducing a second access-control system.

## Concurrency

Privileged profile lifecycle changes are serialized with a transaction advisory lock before the target row is evaluated. This prevents concurrent deactivation requests from bypassing the final-active-Admin invariant within this command boundary.

## Failure behavior

- Missing target: `user_not_found`.
- Missing target ID: `user_id_required`.
- Missing status: `active_required`.
- Self-status change: `self_status_change_forbidden`.
- Final active Admin deactivation: `last_active_admin_protected`.
- Non-Admin actor: `forbidden`.

## Scope separation

- T286: profile name editing.
- T287: role changes.
- T288: activation/deactivation.
- T289/T290: password recovery and Auth invitation state.
- T293: dedicated last-admin acceptance coverage.

## Production

No production database mutation is part of T288 implementation. Migration deployment remains a later release-gated task.
