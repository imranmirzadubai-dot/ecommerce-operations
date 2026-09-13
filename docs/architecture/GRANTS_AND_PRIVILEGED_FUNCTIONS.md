# Grants and Privileged-Function Permissions — T043

## 1. Purpose

This document formalizes the PostgreSQL object-permission contract for the E-Commerce Operations application. It complements the role/permission and RLS contracts and defines which transport roles may reach tables and functions, which functions are privileged, and how execution boundaries must be enforced.

This is a Phase 2 architecture contract. It does not silently implement Phase 3 hardening.

## 2. Roles

Application roles are exactly `sales`, `operations`, and `admin`. PostgreSQL/Supabase transport roles are `anon`, `authenticated`, and `service_role`.

`service_role` is an infrastructure/backend credential, not an application role. It must never be exposed to the browser.

## 3. Direct table-grant contract

| Object class | anon | authenticated | service_role | Direct writes for app roles |
|---|---|---|---|---|
| Operational domain tables | No access | SELECT only where approved by RLS matrix | Backend/infrastructure only | No |
| `financial_adjustments` | No access | Admin-only visibility through target RLS policy | Backend/infrastructure only | No |
| `audit_logs`, `import_batches`, `import_rows` | No access | Admin-only visibility through target RLS policy | Backend/infrastructure only | No |
| `profiles` | No access | Self-only SELECT through RLS | Backend/infrastructure only | No |

Direct `INSERT`, `UPDATE`, and `DELETE` must not be granted to normal application transport roles where the operation is command-owned. RLS is a row-level boundary, not a substitute for least-privilege object grants.

## 4. Function EXECUTE contract

Privileged or command functions must have explicit `EXECUTE` grants. `PUBLIC` and `anon` execution are forbidden for protected application commands.

| Function class | anon | authenticated | Application-role validation |
|---|---|---|---|
| Customer/order commands | Deny | Explicitly grant | Required |
| Lifecycle commands | Deny | Explicitly grant | Required |
| Shipment execution commands | Deny | Explicitly grant | Required |
| Financial/COD exception commands | Deny | Explicitly grant | Required; Admin where specified |
| Historical import/admin commands | Deny | Explicitly grant | Required; Admin |
| Security-definer helpers | Deny | No direct client execution unless explicitly required | Required |

The executable role and the application role are separate checks: an authenticated caller reaching a function does not by itself authorize the business operation.

## 5. SECURITY DEFINER requirements

A `SECURITY DEFINER` function must:

1. use a controlled `search_path`;
2. schema-qualify object references;
3. validate the authenticated caller and authoritative application role inside the transaction;
4. validate lifecycle, financial, allocation, identifier, and other applicable invariants;
5. expose only the minimum required `EXECUTE` privilege;
6. avoid being callable anonymously;
7. avoid lower-level helper paths that allow callers to bypass the command boundary.

Security-definer helper functions should remain outside exposed application schemas when practical.

## 6. Command boundary

The following remain command-owned rather than direct browser-table writes:

- lifecycle transitions;
- financial adjustments;
- COD exception resolution;
- shipment assignment/dispatch and shipment exceptions;
- historical imports;
- race-sensitive state changes;
- identifier generation and immutable identifiers.

Direct table grants must therefore not create an alternate write path around these commands.

## 7. Current implementation verification requirements

Verification must inspect PostgreSQL catalogs for:

- table privileges by `anon`, `authenticated`, and `service_role`;
- function `EXECUTE` privileges;
- `prosecdef` for security-definer functions;
- function `proconfig`/`search_path` configuration;
- exposed-schema placement;
- whether `PUBLIC` or `anon` can execute protected functions;
- application-role validation inside command bodies.

Known staging evidence requiring hardening verification: earlier staging inspection showed some core `SECURITY DEFINER` commands, including `create_order`, `confirm_order`, and `cancel_order`, were executable by `anon`. This is inconsistent with this target contract and must be resolved by a reproducible implementation task before production exposure.

## 8. Relationship to RLS

Object grants answer **can this transport role reach the object?** RLS answers **which rows are visible/mutable when direct table access is exposed?** Command validation answers **is this business operation authorized and valid?** All three layers must agree.

A permissive table grant must not be interpreted as permission to perform a business operation. Conversely, an RLS policy must not be relied upon to repair an excessive function `EXECUTE` grant.

## 9. Required negative properties

- `anon` cannot read protected application tables.
- `anon` cannot execute protected commands.
- Normal application roles cannot directly mutate command-owned state.
- Sales cannot invoke Operations-only or Admin-only commands successfully.
- Operations cannot invoke Admin-only commands successfully.
- No caller can use a helper function to bypass command-level authorization or invariants.
- `service_role` is backend-only.

## 10. Required positive properties

- Authenticated users can execute only explicitly granted commands.
- Each command validates the application role required by the capability matrix.
- Eligible cancellation remains available to all three application roles, subject to lifecycle/financial preconditions.
- Admin-only operations remain Admin-only at the database boundary.

## 11. Source of truth

The version-controlled migration set and command implementations are the executable source of truth. Staging catalog inspection is verification evidence only. Any hardening identified by this contract must be implemented through a dedicated migration/implementation task rather than an undocumented live-database change.
