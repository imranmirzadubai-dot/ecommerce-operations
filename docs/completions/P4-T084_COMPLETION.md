# P4-T084 — Protected Command Authorization Completion

**Task:** P4-T084 — Implement authorization checks for protected commands  
**Phase:** 4 — Auth & Administration  
**Gate:** Access Gate  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P4-T084-20260912-56b5f5de`

## Outcome

Implemented and verified explicit application-role authorization at the transactional command boundary for the two protected cancellation commands whose authorization checks previously accepted any non-null application role:

- `public.cancel_order(uuid,text)`
- `public.cancel_parcel(uuid,text)`

Both now require an authenticated caller whose active application profile role is one of the locked roles:

- `sales`
- `operations`
- `admin`

Cancellation remains intentionally available to all three approved operational roles. This preserves the role matrix for the dedicated T085–T089 permission tests rather than inventing narrower business permissions in T084.

The other protected command functions already enforce the same active-role boundary, including `create_order`, `confirm_order`, customer resolution, and command-idempotency helpers. Admin profile commands remain separately restricted to `admin`.

## Implementation

- Migration: `supabase/migrations/20260912163000_protected_command_authorization.sql`
- Dedicated authorization test: `supabase/tests/database/032_protected_command_authorization.sql`
- Rebuild verification updated for the 34-migration repository chain: `supabase/tests/database/028_database_rebuild_verification.sql`
- Implementation commit: `56b5f5de4a277857e5ae2a01e99d1fcd698450cd`

## Verification

GitHub Actions run **383 / 34699745407** passed:

- application lint;
- TypeScript typecheck;
- unit tests;
- production build;
- fresh local Supabase startup;
- `supabase db reset` from the complete repository migration chain;
- rebuild verification tests.

Dedicated T084 coverage verifies:

- all seven protected command functions exist with canonical signatures;
- all seven are `SECURITY DEFINER`;
- all seven are denied to `anon` and executable by `authenticated` at the SQL grant boundary;
- `cancel_order` explicitly checks the approved application-role set;
- `cancel_parcel` explicitly checks the approved application-role set;
- browser roles retain no direct INSERT/UPDATE/DELETE privileges on protected application tables.

## Scope boundary

T084 establishes command-level authorization enforcement. Sales, Operations, Admin, cancellation, and unauthorized privileged-action behavior are exercised in the dedicated T085–T089 tasks. No production configuration or production data was changed.

The broader legacy pgTAP suite remains outside T084 scope and is not claimed green.
