# P5-T091 Completion Record

- **Task:** P5-T091 — Implement resolve-or-create customer transaction
- **Phase:** Phase 5 — Customer & Order Core
- **Milestone / Gate:** Commercial Gate
- **Status:** Complete
- **Completion date:** 2026-09-12
- **Implementation commit:** `a822591c0af62c3eddff6dacab9e16b1621b07d7`
- **Task Completion Reference:** `ECO-TCR-P5-T091-20260912-a822591c`

## Scope completed

- Added `public.resolve_or_create_customer(text,text,text,text)` as the transactional customer identity command.
- Requires an authenticated active application role: Sales, Operations, or Admin.
- Uses the T090 canonical UAE phone normalization function before identity resolution.
- Resolves an existing customer by unique `normalized_phone` and locks the row during the transaction.
- Creates a new customer when no matching normalized phone exists.
- Handles concurrent creation through the existing unique normalized-phone constraint and `unique_violation` recovery.
- Updates supplied customer contact fields when an existing customer is resolved.
- Returns the customer identity and a `created` flag to distinguish resolution from creation.
- Writes an audit-log entry for every successful resolution/creation operation.
- Anonymous execution is revoked; authenticated execution is granted; browser roles retain no direct table-write privilege.
- Added dedicated regression coverage in `supabase/tests/database/039_resolve_or_create_customer.sql`.
- Updated rebuild verification to the 36-migration chain and added the dedicated customer-resolution test to CI.

## Verification

- GitHub Actions final verification run passed application quality checks and the fresh local Supabase database reset/rebuild plus dedicated customer-resolution regression test.
- The broader legacy pgTAP suite remains outside this task's claimed green verification scope.

## Security / scope boundary

- No production database changes were made.
- No service-role credentials or Auth-admin API were introduced.
- Customer writes remain behind a SECURITY DEFINER transactional command rather than direct browser table privileges.
- The command reuses the approved application-role boundary and T090 canonical phone normalization rather than inventing a separate customer identity rule.
