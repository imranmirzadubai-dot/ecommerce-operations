# P17-T286 — Admin Profile Edit Contract

The profile-edit boundary is a trusted, idempotent, Admin-only state-changing command.

- `public.profiles` remains the authorization/profile store.
- Existing self-only `profiles` RLS is not weakened.
- `public.update_admin_profile(...)` requires an authenticated active Admin through the current `public.app_role()` boundary.
- The only editable profile property in T286 is `name`.
- Role changes, active/inactive status, and Auth email/account state remain separate lifecycle operations.
- The command uses the existing `command_idempotency` foundation so retries with the same key and request hash return the completed result.
- The target profile is locked before update to prevent concurrent lost updates.
- Privileged before/after audit data is recorded through `audit_logs`.
- Input is normalized and bounded server-side.
- Missing target profiles and invalid names fail closed.
- No direct browser table writes or service-role exposure are introduced.
- No production data mutation is part of T286.

UI integration remains under the later P17 UX tasks.
