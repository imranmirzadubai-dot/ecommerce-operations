# T042 — RLS Policy Verification Test Plan

## 1. Objective

Verify that the implemented database security model matches `docs/architecture/RLS_POLICY_MATRIX.md` and the locked v4.0 authorization contract.

This plan is designed for reproducible database/CI execution. Staging checks supplement the test suite but do not replace migration-based verification.

## 2. Test identities

Use isolated test identities/profiles representing:

- unauthenticated (`anon`)
- authenticated Sales (`sales`)
- authenticated Operations (`operations`)
- authenticated Admin (`admin`)
- authenticated user with no active application role/profile

Test fixtures must be disposable and must not use production business data.

## 3. Test matrix

| ID | Test | Expected result |
|---|---|---|
| T042-01 | Anonymous SELECT on every exposed table | Denied/no protected rows |
| T042-02 | Authenticated user with no active role reads role-protected table | Denied/no protected rows |
| T042-03 | Sales SELECT on operational tables | Allowed only where matrix says Sales = Yes |
| T042-04 | Operations SELECT on operational tables | Allowed only where matrix says Operations = Yes |
| T042-05 | Admin SELECT on operational tables | Allowed |
| T042-06 | Sales SELECT on `financial_adjustments` | Denied |
| T042-07 | Operations SELECT on `financial_adjustments` | Denied |
| T042-08 | Admin SELECT on `financial_adjustments` | Allowed |
| T042-09 | Sales SELECT on audit/import administration tables | Denied |
| T042-10 | Operations SELECT on audit/import administration tables | Denied |
| T042-11 | Admin SELECT on audit/import administration tables | Allowed |
| T042-12 | Sales direct INSERT/UPDATE/DELETE on command-owned tables | Denied |
| T042-13 | Operations direct INSERT/UPDATE/DELETE on command-owned tables | Denied |
| T042-14 | Admin direct INSERT/UPDATE/DELETE on command-owned tables | Denied unless an explicitly documented direct-write exception exists |
| T042-15 | Sales invokes Operations-only command | Denied |
| T042-16 | Sales invokes Admin-only command | Denied |
| T042-17 | Operations invokes Admin-only command | Denied |
| T042-18 | Eligible cancellation by Sales | Allowed through command |
| T042-19 | Eligible cancellation by Operations | Allowed through command |
| T042-20 | Eligible cancellation by Admin | Allowed through command |
| T042-21 | Ineligible cancellation by any role | Denied by lifecycle precondition |
| T042-22 | Attempt to mutate identifier/command-owned state through direct table access | Denied |
| T042-23 | Attempt to modify historical event/outcome/receipt records directly | Denied |
| T042-24 | Security-definer function EXECUTE grant review | Only intended authenticated roles can execute |
| T042-25 | Security-definer helper called outside intended command path | Denied or otherwise cannot bypass authorization |
| T042-26 | Role changed from Sales to Admin | Authorization reflects authoritative profile after session/claim freshness handling |
| T042-27 | Inactive profile attempts protected access | Denied |
| T042-28 | Service-role credential used from browser/client path | Must not be present/exposed; backend-only control verified |
| T042-29 | Every public application table has RLS enabled | Pass only if all exposed tables are covered |
| T042-30 | Every public application table has an intentional policy/grant decision | Pass only if no table is unintentionally open or inaccessible |

## 4. Table coverage

The implementation test suite must enumerate the public application tables rather than testing only a hand-picked subset. Current domain tables include:

`profiles`, `customers`, `shippers`, `orders`, `order_items`, `parcels`, `parcel_items`, `delivery_outcomes`, `cod_obligations`, `cod_obligation_allocations`, `cod_receipts`, `financial_adjustments`, `invoice_records`, `order_events`, `audit_logs`, `import_batches`, `import_rows`.

The test should fail if a new exposed table is added without an explicit RLS/grant decision.

## 5. Policy assertions

The database verification should inspect PostgreSQL catalog state (`pg_policies`, table privileges, and function privileges) and assert:

- RLS is enabled for every exposed application table.
- `anon` has no application-table privileges.
- `authenticated` has only explicitly approved direct privileges.
- No unexpected direct INSERT/UPDATE/DELETE grants exist for application roles.
- Admin-only tables are not readable by Sales or Operations.
- `profiles` is readable only for the caller's own row through the direct profile policy.
- Security-definer functions have controlled search paths and explicit execution grants.

## 6. Positive authorization tests

Positive tests must prove the capabilities assigned to each role, not merely that a query returns a row. Command calls must verify the complete transaction succeeds under valid lifecycle/invariant conditions.

## 7. Negative authorization tests

Negative tests are mandatory and must attempt the prohibited path, including direct SQL mutation and unauthorized command execution. A UI omission is not an acceptable negative test.

## 8. Regression requirements

The T042 suite must be run after any change to:

- RLS policies;
- grants/revokes;
- profile role logic;
- security-definer functions;
- command authorization;
- exposed views/tables;
- migrations affecting domain access.

## 9. Completion criteria

T042 verification is PASS only when:

1. the architecture matrix is version-controlled;
2. all exposed tables have explicit RLS/grant decisions;
3. positive and negative role tests are reproducible;
4. the known `financial_adjustments` visibility gap is either fixed by a later Phase 3 migration or formally dispositioned by the authorized owner;
5. no service-role secret is exposed to the client;
6. evidence is recorded against a commit.

A green documentation commit alone does not prove Phase 3 database security implementation.
