# T041 Role and Permission Matrix — Test Plan

## Objective

Verify that the v4.0 Sales, Operations, and Admin role contract is explicit, enforceable, and testable without relying on UI-only restrictions.

## Contract under test

- Roles: `sales`, `operations`, `admin`.
- Auth identity is distinct from application role.
- Capability boundaries match `docs/architecture/PERMISSIONS_AND_RLS.md`.
- Cancellation is available to all three roles only when lifecycle/financial preconditions are satisfied.
- Admin-only capabilities remain inaccessible to Sales and Operations.
- Operations-only shipment execution capabilities remain inaccessible to Sales.
- Command-owned writes are not directly mutable by normal application roles.
- Audit/history records are append-only to normal application roles.
- Unauthenticated callers are denied protected application access.
- Privileged function execution is explicitly granted.

## Verification cases

| ID | Verification | Expected result |
|---|---|---|
| T041-01 | Resolve authenticated user to application role | Exactly one approved role is obtained: Sales, Operations, or Admin |
| T041-02 | Sales positive capability set | Every Sales=Yes capability succeeds when lifecycle preconditions pass |
| T041-03 | Sales negative capability set | Every Sales=No capability is denied |
| T041-04 | Operations positive capability set | Every Operations=Yes capability succeeds when lifecycle preconditions pass |
| T041-05 | Operations negative capability set | Every Operations=No capability is denied |
| T041-06 | Admin positive capability set | Every Admin=Yes capability succeeds when lifecycle preconditions pass |
| T041-07 | Cancellation by Sales | Allowed only when lifecycle/financial eligibility passes |
| T041-08 | Cancellation by Operations | Allowed only when lifecycle/financial eligibility passes |
| T041-09 | Cancellation by Admin | Allowed only when lifecycle/financial eligibility passes |
| T041-10 | Admin-only financial/COD/import/settings operations | Sales and Operations denied; Admin allowed |
| T041-11 | Operations-only shipment execution | Sales denied; Operations/Admin allowed |
| T041-12 | Direct mutation of command-owned protected state | Normal application roles denied |
| T041-13 | Audit/history mutation | Normal application roles cannot update/delete historical records |
| T041-14 | Unauthenticated protected access | Denied |
| T041-15 | Privileged function execution | Only explicitly authorized role can execute each privileged function |
| T041-16 | Role-change/token freshness | Permission changes do not incorrectly depend on stale client-side authorization state |

## Evidence requirements

Execution evidence must come from the reproducible database/command test environment and CI. Live staging inspection may supplement evidence but cannot replace version-controlled migrations.

Each capability should have at least one positive and one negative assertion where applicable. Security-sensitive failures must be treated as blockers for the Architecture Gate.

## Implementation boundary

This test plan defines Phase 2 verification requirements. Concrete RLS policies, grants, commands, fixtures, and pgTAP tests are implementation work for Phase 3 and later tasks unless already present and verifiable in the repository's migration source of truth.
