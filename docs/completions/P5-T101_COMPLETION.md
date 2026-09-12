# P5-T101 — Test Concurrent Customer Creation

**Status:** COMPLETE
**Date:** 2026-09-13

## Scope

Verify the concurrency boundary for customer creation so two concurrent attempts for the same normalized UAE phone cannot create duplicate customer records.

## Verified implementation

The existing customer-resolution path provides the required database concurrency protections:

- `customers.normalized_phone` is protected by the partial unique index `uq_customers_normalized_phone`.
- `resolve_or_create_customer` uses the canonical UAE phone normalization path.
- Existing-customer lookup uses `FOR UPDATE`.
- The insert path catches `unique_violation` and re-reads the customer by normalized phone, then locks the resulting row.
- Browser-authenticated users do not receive direct INSERT/UPDATE/DELETE access to `customers`; customer creation is command/function mediated.

## Test coverage

Added `supabase/tests/database/048_concurrent_customer_creation.sql` with 10 structural assertions covering:

1. normalized-phone unique index presence;
2. canonical `resolve_or_create_customer` signature;
3. authenticated execution permission;
4. anonymous execution denial;
5. `unique_violation` handling;
6. normalized-phone re-read after the race;
7. `FOR UPDATE` locking;
8. UAE phone normalization;
9. `created boolean` result contract;
10. denial of direct customer table writes to authenticated users.

Updated `.github/workflows/ci.yml` so test 048 is included in the database verification suite.

## CI verification

GitHub Actions run **#508 / 34722544801** passed both required jobs:

- Quality: lint, typecheck, unit tests and build — **PASS**
- Local Supabase database tests — **PASS**
- Database suite: **14 files / 156 tests — PASS**
- Test 048: **PASS**
- Database reset/rebuild from repository migrations: **PASS**

No production data was accessed or modified.

## Evidence

- Test: `supabase/tests/database/048_concurrent_customer_creation.sql`
- CI run: `34722544801`
- Implementation/test CI head: `fd8f957f70a34124d4bc7a96d5b8923729f9438d`

## Completion statement

P5-T101 is complete. The repository now has explicit CI coverage for the customer-creation concurrency contract, and the full database rebuild and test suite passes from the repository state.
