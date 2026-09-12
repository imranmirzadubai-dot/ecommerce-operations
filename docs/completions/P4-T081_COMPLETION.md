# P4-T081 — Application Roles Completion

**Task:** P4-T081 — Implement application roles  
**Phase:** 4 — Auth & Administration  
**Gate:** Access Gate  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P4-T081-20260912-bf6a0fad`

## Outcome

Implemented a single, typed application-role definition for the locked three-role model:

- `sales`
- `operations`
- `admin`

The application now centralizes the role set in `src/lib/roles.ts`, exposes runtime validation through `isAppRole`, and provides stable display labels. The existing authentication model imports the same role definition rather than maintaining a second role list.

The database remains authoritative: `public.profiles.role` is already constrained to exactly these three values, and `public.app_role()` resolves the active authenticated profile role. No additional role or permission model was invented in T081.

## Evidence

- Role definition: `src/lib/roles.ts`
- Auth integration: `src/lib/auth.ts`
- Unit tests: `tests/unit/roles.test.mjs`
- Implementation commit: `bf6a0fad7f53ecbf3e30fba0de34d9287c413270`
- CI run: GitHub Actions run `34677513577` / `372`

## Verification

CI run 372 passed:

- application lint;
- TypeScript typecheck;
- unit tests;
- production build;
- fresh local Supabase startup;
- `supabase db reset` from the repository migration chain;
- rebuild verification tests.

The role tests cover all three approved roles, stable labels, and rejection of null, malformed, unsupported, case-mismatched, and non-string values.

The existing database role constraint remains the authoritative enforcement boundary: `profiles.role` is `NOT NULL` and constrained to `sales`, `operations`, or `admin`.

## Scope boundary

T081 establishes and centralizes the application-role model. Active/inactive lifecycle behavior remains T082, administrative user controls remain T083, and command-level authorization remains T084. No production configuration or production data was changed.
