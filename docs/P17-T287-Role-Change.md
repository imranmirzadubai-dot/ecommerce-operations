# P17-T287 — Admin Role Change

## Scope

Implement the trusted server-side role-change boundary for User Management.

## Contract

- Supabase Auth remains the sole identity/account system.
- `public.profiles.role` remains the application authorization field.
- Only an authenticated active Admin may invoke the command.
- Allowed roles are `sales`, `operations`, and `admin`.
- An Admin cannot change their own role.
- The final active Admin cannot be demoted.
- Target profiles are locked with `FOR UPDATE` before authorization-sensitive mutation.
- Existing command idempotency is required for safe retries.
- The mutation records before/after role state in `audit_logs`.
- The function is `SECURITY DEFINER` with a pinned `search_path` and restricted `EXECUTE`.
- Existing `profiles` RLS is not weakened.
- No service-role credential is exposed to the browser.

## Separation of concerns

- Profile name editing is handled by P17-T286.
- Role changes are handled here.
- Activation/deactivation remains P17-T288.
- Password recovery and Auth invitation state remain P17-T289/T290.
- Dedicated last-admin acceptance coverage remains P17-T293; this command already enforces the safety invariant.

## Failure safety

The command uses the existing idempotency transaction boundary. A failed validation, target lookup, authorization check, mutation, or audit write rolls back the transaction, allowing a safe retry with the same idempotency key.

## Production safety

No production database mutation is part of T287 implementation. Deployment and production verification remain later P17 tasks.
