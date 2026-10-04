# P17-T293 — Final Active Admin Protection

## Purpose

Protect the system from reaching a state with zero active Admin profiles.

## Enforcement

The trusted Admin role/status commands already enforce the invariant. This task adds a database-level defense-in-depth trigger on `public.profiles` so future mutation paths cannot bypass it.

The trigger rejects any update that changes the final active Admin from `(role = 'admin', active = true)` to a state that is not both Admin and active.

## Concurrency

The trigger takes a transaction-scoped advisory lock before counting other active Admins. This serializes privileged role/status transitions and prevents two concurrent mutations from both observing the same final Admin and removing the last protection.

## Security

- `SECURITY DEFINER` with pinned `search_path`.
- Function execution is revoked from `public`.
- No RLS changes.
- No service-role or browser secret exposure.
- Existing T287/T288 trusted command checks remain the primary application boundary.
- Existing T291/T292 database guards remain in place.

## Expected behavior

- Final active Admin → inactive: **blocked**.
- Final active Admin → Sales/Operations: **blocked**.
- Final active Admin → inactive non-Admin in one update: **blocked**.
- Active Admin → another active Admin: **allowed**.
- Non-final active Admin → inactive/non-Admin: **allowed** when authorized.
- Promoting another user to active Admin remains **allowed**.
