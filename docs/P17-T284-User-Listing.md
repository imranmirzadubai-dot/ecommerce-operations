# P17-T284 — Admin User Listing Contract

The user-management listing boundary is read-only and Admin-only.

- `public.profiles` remains the authorization/profile store.
- Existing self-only `profiles` RLS is not weakened.
- `public.admin_list_profiles(...)` is a `SECURITY DEFINER` read boundary with a pinned `search_path`.
- The function requires an authenticated actor whose current application role is `admin`.
- Supported filters are normalized search, role, and active status.
- Pagination is bounded to a maximum of 100 rows per call.
- Returned properties are explicitly allowlisted: id, name, email, role, active, created_at, updated_at, and total_count.
- No Auth secrets, tokens, password fields, or other Auth internals are exposed.
- Invalid roles are rejected server-side.
- No production data mutation is part of T284.

UI integration remains a later UX task; this migration establishes the trusted read contract required for the Admin Users screen.
