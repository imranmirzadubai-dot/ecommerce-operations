# P4-T079 — Implement protected application routes

**Status:** Complete  
**Completed:** 2026-09-12  
**TCR:** ECO-TCR-P4-T079-20260912-<commit-short-sha>

## Scope

Implemented the authentication route boundary for the existing single-page React application without introducing a second routing framework.

## Implementation

- Added a typed route policy in `src/lib/routes.ts`.
- `/login` is the explicit public route.
- Application paths are treated as protected by default.
- Added `src/RouteGuard.tsx` at the application mount boundary.
- Protected routes restore and validate the existing authenticated session before mounting the application, preventing protected workspace content from flashing while authentication is unresolved.
- Unauthenticated protected-route access redirects to `/login` with an encoded, same-origin return path.
- Sign-in returns to the validated requested path.
- Sign-out returns to the public login route.
- Return-path handling rejects protocol-relative, absolute, backslash-containing, and non-path destinations to prevent open redirects.

## Verification

GitHub Actions CI run **34676294905 / run 366** on `feature/t057-parcels-foundation` passed:

- Lint — success
- Typecheck — success
- Unit tests — success
- Build — success
- Local Supabase database reset from migrations — success
- Rebuild verification tests — success

Dedicated route-policy tests are in `tests/unit/routes.test.mjs` and cover public/protected classification, encoded return paths, and negative open-redirect cases.

## Boundary notes

T079 establishes authentication-based route protection only. Profile creation/linking, application roles, account lifecycle, admin controls, and command-level authorization remain in their scheduled T080+ tasks and are not claimed by this completion.

No production deployment or production data was changed.
