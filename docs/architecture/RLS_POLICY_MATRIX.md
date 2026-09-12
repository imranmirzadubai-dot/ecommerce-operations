# RLS Policy Matrix — v4.0

## 1. Purpose

This document is the Phase 2 authorization/RLS contract for the E-Commerce Operations application. It converts the role and permission contract into an explicit table-by-table Row Level Security (RLS), direct-grant, and command-boundary matrix.

The locked Master Implementation Plan v4.0 requires Phase 2 to produce exact RLS policies and Phase 3 to implement schema, RLS, grants, transactional functions, and security tests. This document is therefore the architectural target; it does not silently replace the Phase 3 implementation tasks.

## 2. Security model

Authorization is layered:

1. Supabase Auth establishes identity.
2. `public.profiles.role` is the authoritative application role (`sales`, `operations`, `admin`) and must be active.
3. PostgreSQL object privileges determine whether the transport role can reach an object.
4. RLS determines row visibility/mutability for direct table access.
5. Sensitive and race-sensitive writes use server-side transactional commands.
6. The UI is presentation only and cannot grant authority.

`anon` must have no application-table access. `authenticated` may receive only explicitly approved direct privileges. `service_role` is backend-only and is not a browser authorization mechanism.

## 3. Policy vocabulary

- **S** = direct SELECT is permitted through RLS.
- **I** = direct INSERT is permitted through RLS.
- **U** = direct UPDATE is permitted through RLS.
- **D** = direct DELETE is permitted through RLS.
- **Command** = state change must occur through an authorized transactional command rather than direct table mutation.
- **None** = no direct application access for the role.

For this MVP, direct browser writes are intentionally absent from command-owned domain tables. Consequently, the target matrix has no direct `I/U/D` permissions for Sales, Operations, or Admin on those tables.

## 4. Table-by-table RLS matrix

| Table | Sales S | Operations S | Admin S | Sales I/U/D | Ops I/U/D | Admin I/U/D | Write boundary | Notes |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|---|
| `profiles` | Self only | Self only | Self only | No | No | No | Admin/account command | Users cannot alter role/active state directly. |
| `customers` | Yes | Yes | Yes | No | No | No | Customer/order commands | Operational customer history is shared. |
| `shippers` | Yes | Yes | Yes | No | No | No | Admin/operations command | Sales may read available shippers but cannot assign them. |
| `orders` | Yes | Yes | Yes | No | No | No | Order/lifecycle commands | Includes order history. |
| `order_items` | Yes | Yes | Yes | No | No | No | Order commands | Must follow order lifecycle/invariants. |
| `parcels` | Yes | Yes | Yes | No | No | No | Parcel/dispatch/lifecycle commands | Direct state mutation prohibited. |
| `parcel_items` | Yes | Yes | Yes | No | No | No | Allocation commands | Allocation is invariant-protected. |
| `delivery_outcomes` | Yes | Yes | Yes | No | No | No | Delivery/RTO commands | Append-only operational history. |
| `cod_obligations` | Yes | Yes | Yes | No | No | No | COD commands | Readable for COD/invoice workflow. |
| `cod_obligation_allocations` | Yes | Yes | Yes | No | No | No | COD commands | Read-only reconciliation data. |
| `cod_receipts` | Yes | Yes | Yes | No | No | No | COD receipt command | One receipt per parcel; immutable operational record. |
| `financial_adjustments` | **No** | **No** | **Yes** | No | No | No | Admin financial-adjustment command | Financial correction records are admin-only. |
| `invoice_records` | Yes | Yes | Yes | No | No | No | Invoice command | Read-only generated-record access. |
| `order_events` | Yes | Yes | Yes | No | No | No | Transactional commands | Historical event evidence is append-only. |
| `audit_logs` | No | No | Yes | No | No | No | Server-side audit writer | Admin read access only; normal roles cannot mutate. |
| `import_batches` | No | No | Yes | No | No | No | Import commands | Historical import is Admin-only. |
| `import_rows` | No | No | Yes | No | No | No | Import commands | Raw/normalized import evidence is Admin-only. |

## 5. Unauthenticated behavior

`anon` has no direct access to application tables. Requests without an authenticated identity must not obtain protected application data through RLS, views, or direct table privileges.

An authenticated user without an active application profile/role is not an application-authorized user. Role-dependent policies must fail closed when `public.app_role()` is null.

## 6. Role behavior

### Sales

Sales can read the shared operational workflow required for customer/order/delivery-facing work. Sales cannot directly write domain tables and cannot read privileged financial-adjustment, audit, or historical-import administration records.

Sales cannot execute Operations-only or Admin-only commands.

### Operations

Operations has the same operational read visibility as Sales and additionally performs shipment execution through authorized commands. Operations cannot directly write domain tables and cannot read privileged financial-adjustment, audit, or historical-import administration records.

Operations cannot execute Admin-only commands.

### Admin

Admin has operational read visibility plus privileged administrative read visibility for financial adjustments, audit logs, and import staging/history. Admin writes remain command-mediated and must still satisfy lifecycle, financial, COD, allocation, and audit invariants.

Admin is not a bypass for business-state preconditions.

## 7. Relationship-based access rules

The current MVP does not define tenant-, branch-, or salesperson-owned row partitions. Customer/order operational data is therefore shared across the three application roles that are authorized to use it.

Where a future relationship-scoped policy is introduced, the policy must be expressed as a database predicate based on authoritative relationships, not a client-supplied identifier. Examples include:

- order -> customer relationship;
- parcel -> order relationship;
- parcel_item -> parcel/order_item relationship;
- delivery outcome -> parcel relationship;
- COD allocation -> COD obligation/parcel relationship;
- invoice -> order relationship;
- event -> order/parcel relationship;
- import row -> import batch relationship.

No policy may trust a browser-supplied role, ownership flag, or unrestricted foreign-key value as proof of authorization.

## 8. Direct-write policy

The target direct-write policy for browser application roles is:

- `INSERT`: denied on command-owned domain tables.
- `UPDATE`: denied on command-owned domain tables.
- `DELETE`: denied on command-owned domain tables.

This is intentional. RLS is not being used as a substitute for domain commands. Transactional commands perform role checks, lifecycle checks, invariant checks, and audit/event recording atomically.

Hard deletion is not an ordinary application operation for business records. Cancellation is a state transition, not deletion.

## 9. SECURITY DEFINER interaction

RLS is the direct-table boundary; `SECURITY DEFINER` functions are the controlled command boundary where elevated table access is required.

Every security-definer command must:

- use a controlled `search_path`;
- schema-qualify database object references where appropriate;
- have explicit `EXECUTE` grants;
- validate the authenticated caller and application role inside the function;
- enforce lifecycle and domain invariants in the same transaction;
- avoid exposing a lower-level write function that allows callers to bypass the command contract.

A security-definer function must not become an authorization bypass simply because the underlying table has restrictive RLS.

## 10. Service-role boundary

`service_role` is an infrastructure/backend credential, not an application role. It must remain server-side. It is not granted to browser clients and is not used to determine whether Sales, Operations, or Admin may perform a business action.

Any backend use of service-role access must still call the appropriate domain command and preserve actor identity/audit information.

## 11. Audit and immutable-history rules

The following records are historical evidence and are not directly mutable by normal application roles:

- `delivery_outcomes`
- `cod_receipts`
- `financial_adjustments`
- `order_events`
- `audit_logs`
- completed import evidence

Corrections must create the appropriate new command/event/adjustment rather than silently overwriting historical evidence.

## 12. Current implementation comparison

The existing foundation migration establishes the principal security posture: RLS is enabled on all listed application tables, `anon` has no table access, `authenticated` has explicit SELECT grants, and no direct table write grants are provided.

The existing T041 authorization contract requires RLS on every exposed domain table, command-owned sensitive writes, explicit function execution boundaries, append-only audit/history behavior, and positive/negative authorization tests.

One concrete T042 refinement is required: the target matrix makes `financial_adjustments` Admin-read-only. The current foundation migration grants SELECT on `financial_adjustments` to all `authenticated` users, even though financial adjustment capability is Admin-only.

This is recorded as a Phase 3 implementation/security-test requirement rather than being silently changed during Phase 2 formalization.

## 13. Required Phase 3 implementation mapping

Phase 3 must translate this contract into reproducible migrations and security tests covering at minimum:

1. exact policy definitions for every exposed table;
2. `anon` denial;
3. active-role requirement;
4. Sales/Operations/Admin positive reads;
5. Admin-only reads for privileged tables;
6. direct INSERT/UPDATE/DELETE denial;
7. command EXECUTE grants;
8. command role denial tests;
9. lifecycle/invariant bypass attempts;
10. audit/history immutability;
11. role/profile changes and token freshness;
12. service-role/backend boundary.

The migration set and CI tests are the executable source of truth. Staging verification is supporting evidence, not a substitute for reproducible implementation.

## 14. Phase 2 decision

**T042 architecture contract: FORMALIZED.**

**Implementation status: NOT YET COMPLETE.**

The matrix identifies one known implementation refinement (`financial_adjustments` read visibility) that must be implemented and tested in Phase 3. T042 should not claim that Phase 3 security implementation is complete merely because the current foundation has RLS enabled.
