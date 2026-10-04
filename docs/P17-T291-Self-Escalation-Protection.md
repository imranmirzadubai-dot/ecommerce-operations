# P17-T291 — Prevent Self-Escalation

## Scope

Add a database-level defense-in-depth control preventing an authenticated user from changing their own privileged application state.

## Contract

- A user cannot change their own `profiles.role`.
- A user cannot change their own `profiles.active` state.
- Existing trusted Admin commands remain the primary authorization boundary and already reject self role/status changes.
- The database trigger protects against future or accidental mutation paths that might bypass those command-level checks.
- The trigger does not weaken RLS or expose service-role credentials.
- The trigger uses `SECURITY DEFINER` with a pinned `search_path`.
- Non-authenticated/internal operations where `auth.uid()` is null are not treated as user self-escalation; existing trusted server boundaries remain responsible for authorization.

## Separation of concerns

- T287 protects the role-change command.
- T288 protects the activation/deactivation command.
- T291 adds a database-level defense-in-depth invariant covering both privileged profile fields.
- Last-active-Admin protection remains T293; T287/T288 already enforce the underlying invariant in their respective commands.

## Production safety

No production database mutation is part of T291 implementation. Migration deployment and production verification remain later P17 tasks.
