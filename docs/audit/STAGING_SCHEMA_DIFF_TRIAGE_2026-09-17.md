# Staging Schema Diff Triage — 2026-09-17

## Purpose

Translate the verified staging-vs-clean-main object diff into a forward-only reconciliation plan without applying DDL to staging or production.

## Evidence baseline

- Clean-main schema: fresh local Supabase reset from the current reconciliation branch.
- Staging: live PostgreSQL catalog definitions from project `mijbpvgxrxjaalimyqgm`.
- Current diff: `docs/audit/STAGING_VS_CLEAN_MAIN_SCHEMA_DIFF_2026-09-17.md`.
- Data-collision check completed before any corrective uniqueness work:
  - `invoice_records.invoice_number`: 0 duplicate groups.
  - `parcel_items (parcel_id, order_item_id)`: 0 duplicate groups.
  - `orders.order_number`: 0 duplicate groups.
- No staging or production DDL has been executed.

## Triage matrix

| Area | Observed delta | Classification | Required action before production |
|---|---|---|---|
| `invoice_template_versions` | Present in clean-main, absent in staging | Additive | Reconstruct exact table, constraints, indexes, RLS, triggers and dependencies from clean-main; verify invoice-record lineage/data compatibility. |
| `invoice_print_events` | Present in clean-main, absent in staging | Additive | Reconstruct exact table, constraints, indexes, RLS, triggers and dependencies from clean-main; verify invoice-record/order references. |
| `invoice_records.source_snapshot` | Required in clean-main, absent in staging | Additive/data-contract | Determine how existing invoice records receive a valid object snapshot before adding `NOT NULL`; do not invent historical values. |
| Invoice template-version FK | Present in clean-main, absent in staging | Additive/relational | Add only after template-version data and invoice-record references are reconciled. |
| `update_order` | Present in clean-main, absent in staging | Behavioral | Add exact current command contract after authorization/idempotency/dependency review and DB regression coverage. |
| Parcel allocation helpers/commands | Multiple clean-main functions absent in staging | Behavioral | Add as a coherent dependency group in migration order; verify grants, security-definer search path, authorization and invariants. |
| Profile/customer helpers | `create_profile`, `set_profile_active`, UAE phone/resolve-or-create functions absent | Behavioral | Reconcile role/profile lifecycle and customer phone normalization contracts before adding. |
| Invoice immutability/snapshot/print functions | Multiple clean-main functions absent | Behavioral | Add together with their dependent tables/columns and exact grants/triggers. |
| RLS policies | 3 clean-main policies absent | Security | Add after target tables/roles are present; verify policy predicates and grants exactly against clean-main. |
| Non-constraint indexes | 5 clean-main indexes absent | Additive/performance | Add after their parent tables/columns exist; verify uniqueness/partial predicates and index definitions. |
| `parcel_items` composite uniqueness | Clean-main boundary absent; 0 duplicate groups found | Corrective/additive | Add exact clean-main constraint/index after confirming NULL semantics and existing allocation-state behavior. |
| Duplicate `orders` checks | Two duplicate logical checks in staging | Corrective | Do not drop blindly. First identify the canonical current-main constraint and verify dependent code/tests; then remove redundant legacy definition in a separately reviewable migration. |
| Duplicate `invoice_records` uniqueness | Two duplicate logical unique constraints in staging | Corrective | Do not drop blindly. Verify canonical clean-main definition, dependent indexes/FKs, and constraint names before removing the redundant legacy object. |
| Staging-only unexplained provenance | Historical ledger does not explain all current objects | Legacy/unverified | Preserve until provenance is established or a controlled canonical baseline decision is documented. |

## Dependency order for the forward path

1. Establish a disposable database from the exact current repository migrations and capture its final public schema.
2. Reconcile foundational table/column definitions first, including invoice lineage prerequisites.
3. Reconcile constraints and indexes, separating additive boundaries from duplicate legacy definitions.
4. Reconcile RLS, grants, triggers and security-definer functions as a dependency graph rather than by filename order alone.
5. Reconcile application command functions and client contracts.
6. Add targeted regression tests for every material staging delta, especially invoice lineage, parcel allocation uniqueness, profile/customer lifecycle and RLS.
7. Build a forward-only candidate migration path in a disposable copy of the staging schema.
8. Re-run the same catalog comparison until the intended schema delta is zero, apart from explicitly documented legacy objects that are intentionally retained.
9. Only after that should a separate deployment plan be considered for staging, followed by production under the normal review/merge gate.

## Important data decision

`invoice_records.source_snapshot` is the only identified missing `NOT NULL` column that cannot be safely populated from existence/uniqueness checks alone. The reconciliation must determine whether historical invoice source data exists elsewhere or whether the canonical forward path must preserve existing rows through a documented backfill rule. A fabricated empty object is not an acceptable substitute for historical source data.

## Gate

This document is a triage plan and evidence record. It does not authorize DDL execution. No staging reset, production DDL, migration-ledger manipulation, or destructive cleanup is permitted from this document alone.
