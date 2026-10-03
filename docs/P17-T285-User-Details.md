# P17-T285 — Admin User Details Contract

The user-details boundary is read-only and Admin-only.

- `public.profiles` remains the authorization/profile store.
- Existing self-only `profiles` RLS is not weakened.
- `public.admin_get_profile(uuid)` is a `SECURITY DEFINER` read boundary with a pinned `search_path`.
- The function requires an authenticated actor whose current application role is `admin`.
- The target user is selected by an explicit UUID parameter, preventing client-controlled row predicates from becoming a direct table access path.
- Returned properties are explicitly allowlisted: id, name, email, role, active, created_at, and updated_at.
- No Auth secrets, tokens, password fields, or other Auth internals are exposed.
- A null target UUID is rejected server-side.
- A missing target profile returns no row; it does not expose another user's data.
- No production data mutation is part of T285.

UI integration remains under the later P17 UX tasks. Account invitation, email verification state, password recovery, and session controls remain separate lifecycle tasks.
