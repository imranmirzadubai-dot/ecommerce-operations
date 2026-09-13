# Role and Permission Matrix — v4.0

## 1. Purpose

This document is the Phase 2 authorization contract for the E-Commerce Operations application. It defines the application roles, business capabilities, authorization boundaries, and database-enforcement requirements that implementation must preserve.

This is a contract, not a UI checklist. Hiding a button is never sufficient authorization.

## 2. Application roles

Exactly three application roles are defined for v4.0:

- `sales`
- `operations`
- `admin`

Supabase Auth establishes user identity. A protected application profile establishes the application role. The browser may use the role for presentation, but PostgreSQL authorization must independently enforce the permission boundary.

The application roles are distinct from Supabase/PostgreSQL transport roles such as `anon`, `authenticated`, and `service_role`.

## 3. Capability matrix

| Capability | Sales | Operations | Admin | Required boundary |
|---|:---:|:---:|:---:|---|
| Customer/order history | Yes | Yes | Yes | Authenticated + application role |
| Create/edit pre-confirmed order | Yes | Yes | Yes | Command/lifecycle validation |
| Delivery/NDR | Yes | Yes | Yes | Command/lifecycle validation |
| Eligible cancellation | Yes | Yes | Yes | Lifecycle preconditions; not role-restricted |
| Invoice/COD receipt | Yes | Yes | Yes | Command/lifecycle validation |
| Shipper assignment | No | Yes | Yes | Operations/Admin command |
| Dispatch | No | Yes | Yes | Operations/Admin command |
| RTO/Lost/Damaged | No | Yes | Yes | Operations/Admin command |
| COD exception resolution | No | No | Yes | Admin-only command |
| Financial adjustment | No | No | Yes | Admin-only command + financial invariants |
| Historical import | No | No | Yes | Admin-only command + audit trail |
| User/settings administration | No | No | Yes | Admin-only command |

## 4. Explicit authorization rules

### 4.1 Sales

Sales may perform the ordinary customer/order and delivery-facing workflow defined above. Sales must not perform shipper assignment, dispatch, RTO/Lost/Damaged resolution, COD exception resolution, financial adjustment, historical import, or user/settings administration.

### 4.2 Operations

Operations inherits Sales capabilities and additionally owns shipment execution: shipper assignment, dispatch, and RTO/Lost/Damaged handling. Operations must not resolve COD exceptions, perform financial adjustments, import historical records, or administer users/settings.

### 4.3 Admin

Admin has all capabilities in the matrix, including the privileged financial, exception, historical-import, and user/settings operations.

Admin is not a bypass for lifecycle invariants. Business-state preconditions remain mandatory even for Admin commands.

## 5. Cancellation rule

Cancellation is deliberately **not role-restricted**. Sales, Operations, and Admin may request an eligible cancellation, but the command must enforce the lifecycle/financial preconditions defined by the application contracts. Authorization and lifecycle validity are separate checks.

## 6. Database enforcement model

Authorization is enforced in layers:

1. Supabase Auth authenticates the caller.
2. The protected application role identifies `sales`, `operations`, or `admin`.
3. Explicit PostgreSQL grants determine whether the transport role can reach an object at all.
4. RLS policies determine which rows are visible or mutable where direct table access is intentionally exposed.
5. Privileged and race-sensitive state changes execute through server-side transactional commands with explicit `EXECUTE` grants.
6. UI role checks are presentation only and cannot grant authority.

RLS must be enabled on every application-exposed domain table. Any exposed table without an appropriate RLS policy is a security defect.

## 7. Command boundary

Sensitive writes must not depend on direct browser table mutation. Commands are the authoritative write boundary for:

- lifecycle transitions;
- financial adjustments;
- COD exception resolution;
- shipment execution and exception handling;
- historical imports;
- any race-sensitive state change;
- identifier generation and immutable identifier fields.

Normal application roles should receive only the direct table privileges necessary for explicitly approved read paths. They must not receive direct `INSERT`/`UPDATE` authority where a command is the required write boundary.

## 8. Privileged functions

Privileged functions must:

- have explicit `EXECUTE` grants only to roles that need them;
- use `SECURITY DEFINER` only when required;
- use a controlled `search_path` and schema-qualified object references when `SECURITY DEFINER` is used;
- remain outside exposed schemas when they are security-definer helpers;
- validate the caller's application role and all relevant business invariants inside the transaction.

Service-role or secret credentials must never be delivered to the browser.

## 9. Role storage and authorization source

The protected application role is authoritative for application authorization. User-editable metadata must not be treated as the source of truth for permissions.

If JWT claims are used to accelerate RLS decisions, the claim must originate from a trusted server-side/auth-hook path and the design must account for token staleness. Permission-changing workflows must not assume that a stale browser token immediately reflects a role change.

## 10. Audit and historical records

Audit/event records are append-only to normal application roles. Historical operational records are not editable or deletable through ordinary application access.

Privileged administrative actions must preserve actor identity and the command/audit trail required by the observability and financial contracts.

## 11. Negative authorization requirements

The following are mandatory security properties:

- Sales cannot execute Operations-only commands.
- Sales cannot execute Admin-only commands.
- Operations cannot execute Admin-only commands.
- No application role can bypass lifecycle preconditions by changing UI state or calling a lower-level write path.
- Normal application roles cannot directly mutate protected identifier fields or other command-owned state.
- Unauthenticated callers cannot access protected application data.
- Service-role access is backend-only and never exposed to the browser.

## 12. Positive authorization requirements

The following must also be demonstrably true:

- Sales can perform every capability explicitly marked Yes for Sales.
- Operations can perform every capability explicitly marked Yes for Operations.
- Admin can perform every capability explicitly marked Yes for Admin.
- Eligible cancellation works for all three application roles when lifecycle/financial preconditions pass.
- Read access is granted only to the tables/rows required by the approved workflow.

## 13. Testing contract

The implementation test suite must include both positive and negative tests for every role. At minimum, verification must cover:

1. role resolution from an authenticated identity;
2. read access by role;
3. permitted commands by role;
4. denied commands by role;
5. cancellation for all roles with lifecycle qualification;
6. Admin-only financial/COD/import/settings operations;
7. Operations-only shipment execution operations;
8. direct table-write denial where commands own the write boundary;
9. audit immutability;
10. unauthenticated denial;
11. privileged function `EXECUTE` boundaries;
12. role-change behavior and token/claim freshness where JWT claims are used.

## 14. Implementation rule

This Phase 2 document defines the target contract. It does not prematurely implement the complete RLS/command matrix. Phase 3 implementation tasks must map each capability to concrete commands, tables, policies, grants, and pgTAP/security evidence without weakening this contract.

## 15. Source-of-truth rule

The version-controlled migration set and application command implementation must become the executable source of truth before this contract is considered fully verified. Live staging inspection may provide evidence, but it does not replace reproducible migrations and CI tests.
