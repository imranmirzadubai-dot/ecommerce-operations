# P4-T080 — Profile Creation / Linking Completion

**Task:** P4-T080 — Implement profile creation/linking  
**Phase:** 4 — Auth & Administration  
**Gate:** Access Gate  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P4-T080-20260912-2c732132`

## Outcome

Implemented a controlled `public.create_profile(uuid, text, text)` database command that links an existing Supabase Auth identity to an application `public.profiles` row.

The command:

- requires an authenticated caller;
- requires the caller's active application role to be `admin`;
- validates the target Auth user exists in `auth.users`;
- derives the profile email from the Auth identity rather than trusting a browser-supplied email;
- validates the application role against the locked `sales`, `operations`, `admin` role set;
- creates an active profile linked by the existing `profiles.id -> auth.users.id` relationship;
- is exposed only through the authenticated command boundary, with `anon` execution revoked;
- uses `SECURITY DEFINER` with a controlled `search_path`.

No automatic/default role was invented and no client-controlled Auth metadata is treated as authoritative.

## Evidence

- Migration: `supabase/migrations/20260912160000_profile_creation_linking.sql`
- Test: `supabase/tests/database/029_profile_creation_linking.sql`
- Rebuild verification updated for the new migration and command: `supabase/tests/database/028_database_rebuild_verification.sql`
- Implementation commit: `2c7321329a1ac043642f2bc032934535a08c746e`
- CI run: GitHub Actions run `34676913796` / `370`

## Verification

CI run 370 passed:

- application lint;
- TypeScript typecheck;
- unit tests;
- production build;
- fresh local Supabase startup;
- `supabase db reset` from the repository migration chain;
- rebuild verification tests;
- rebuild smoke tests.

The rebuild verification confirms the repository migration chain now contains 31 migrations and explicitly verifies the new profile command's controlled `SECURITY DEFINER` search path.

## Scope boundary

T080 establishes the secure database-side profile creation/linking boundary. Role mutation, active/inactive lifecycle controls, and the administrative user-management UI remain separate Phase 4 tasks (T081–T083). No production configuration or production data was changed.
