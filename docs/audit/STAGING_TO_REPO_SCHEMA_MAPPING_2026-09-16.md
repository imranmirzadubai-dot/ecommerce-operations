# Staging → Repository Schema Mapping — 2026-09-16

## Purpose

This matrix is the reconciliation control requested by the audit: a table existing in staging is **not** considered equivalent merely because the table name exists. Each application table must be checked across:

1. columns and data types/defaults/nullability;
2. primary/foreign/unique/check constraints;
3. indexes (including partial/functional indexes);
4. RLS enabled state and policy definitions;
5. triggers and immutable/protection behavior;
6. related functions/commands and grants where the table participates in a command boundary;
7. current repository migration source(s) that introduce or modify those objects.

A row is not eligible for a final **MATCHED** status until all applicable dimensions are verified.

## Verified staging baseline

Staging project: `mijbpvgxrxjaalimyqgm`

Observed public schema:
- 18 application tables
- 142 columns
- 95 constraints
- 66 indexes
- 17 RLS policies
- 6 triggers

The current repository's `20260910212711_database_foundation_v4.sql` explicitly creates the same 18 application tables and the baseline columns/relationships. This establishes a strong structural correspondence, but **does not by itself prove final equivalence** because later repository migrations harden constraints, indexes, policies, triggers, functions, and commands.

## Table-level matrix

| Table | Current repo baseline/source | Known current-repo hardening/feature sources | Staging object present? | Deep-diff status |
|---|---|---|---|---|
| profiles | `20260910212711_database_foundation_v4.sql` | `20260912090000_profiles_role_model.sql`; `20260912160000_profile_creation_linking.sql`; `20260912161000_profile_active_lifecycle.sql`; `20260912162000_admin_user_controls.sql`; `20260912163000_protected_command_authorization.sql` | Yes | **OPEN — deep diff required** |
| customers | `20260910212711_database_foundation_v4.sql` | `20260912093000_customers_phone_uniqueness.sql`; `20260912165000_uae_phone_normalization.sql`; `20260912165500_resolve_or_create_customer.sql` | Yes | **OPEN — deep diff required** |
| shippers | `20260910212711_database_foundation_v4.sql` | `20260912094500_shippers_foundation.sql` | Yes | **OPEN — deep diff required** |
| orders | `20260910212711_database_foundation_v4.sql` | `20260912095500_orders_aed_constraint.sql`; `20260912131500_relational_constraints_hardening.sql`; `20260913090000_pre_confirmation_order_editing.sql`; `20260913100000_order_confirmation.sql`; `20260913110000_original_amount_immutability.sql` | Yes | **OPEN — known function gap: `update_order` not present in staging** |
| order_items | `20260910212711_database_foundation_v4.sql` | `20260912100000_order_items_line_uniqueness.sql`; `20260913120000_order_item_immutability.sql` | Yes | **OPEN — deep diff required** |
| parcels | `20260910212711_database_foundation_v4.sql` | `20260912101500_parcels_foundation.sql`; `20260912131500_relational_constraints_hardening.sql`; `20260913140000_parcel_creation.sql`; `20260913150000_parcel_allocation_command.sql`; `20260913160000_split_parcel_allocation.sql`; `20260913160100_correct_parcel_allocation.sql`; `20260913200000_post_dispatch_allocation_immutability.sql` | Yes | **OPEN — deep diff required** |
| parcel_items | `20260910212711_database_foundation_v4.sql` | `20260912103000_parcel_item_allocation_invariants.sql`; `20260912104500_parcel_item_allocation_trigger_hardening.sql`; `20260913150000_parcel_allocation_command.sql`; `20260913160000_split_parcel_allocation.sql`; `20260913160100_correct_parcel_allocation.sql`; `20260913200000_post_dispatch_allocation_immutability.sql` | Yes | **OPEN — deep diff required** |
| delivery_outcomes | `20260910212711_database_foundation_v4.sql` | `20260912110000_delivery_outcomes_immutable.sql`; later P10 command migrations are on open PRs | Yes | **OPEN — trigger/command boundary requires verification** |
| cod_obligations | `20260910212711_database_foundation_v4.sql` | `20260912111500_cod_obligations_hardening.sql` | Yes | **OPEN — deep diff required** |
| cod_obligation_allocations | `20260910212711_database_foundation_v4.sql` | `20260912131500_relational_constraints_hardening.sql`; allocation command migrations | Yes | **OPEN — deep diff required** |
| cod_receipts | `20260910212711_database_foundation_v4.sql` | `20260912113000_cod_receipts_parcel_uniqueness.sql` | Yes | **OPEN — deep diff required** |
| financial_adjustments | `20260910212711_database_foundation_v4.sql` | `20260912114500_financial_adjustments_append_only.sql` | Yes | **OPEN — trigger/protection requires verification** |
| invoice_records | `20260910212711_database_foundation_v4.sql` | `20260912120000_invoice_records_hardening.sql`; `20260914010000_invoice_template_version_lineage.sql`; `20260914020000_invoice_print_event_tracking.sql`; `20260914030000_invoice_historical_reprint_snapshot.sql` | Yes | **OPEN — staging lacks `invoice_template_versions` table, so later invoice lineage is not present** |
| order_events | `20260910212711_database_foundation_v4.sql` | `20260912121500_order_events_immutable.sql` | Yes | **OPEN — deep diff required** |
| audit_logs | `20260910212711_database_foundation_v4.sql` | `20260912123000_audit_logs_immutable.sql` | Yes | **OPEN — deep diff required** |
| import_batches | `20260910212711_database_foundation_v4.sql` | `20260912124500_import_batches_rows_hardening.sql` | Yes | **OPEN — deep diff required** |
| import_rows | `20260910212711_database_foundation_v4.sql` | `20260912124500_import_batches_rows_hardening.sql` | Yes | **OPEN — deep diff required** |
| command_idempotency | current repo `20260911130000_command_idempotency.sql` and retrofit/reconciliation migrations | `20260911140000_command_idempotency_retrofit.sql`; `20260911150000_idempotency_schema_reconciliation.sql` | Yes | **OPEN — deep diff required** |

## Important concrete findings

### 1. The 18 tables are not the whole comparison

The current repository foundation creates all 18 staging application tables, but later migrations alter the behavior of those same tables. Therefore the correct unit of reconciliation is:

`table → columns → constraints → indexes → RLS → triggers → functions/grants → repository migration sources`.

### 2. Staging contains selected later command functions

The current staging database exposes functions including `create_order`, `confirm_order`, `cancel_order`, `cancel_parcel`, `normalize_phone`, and `resolve_customer_by_phone`. This means the staging schema cannot be dated solely from the migration-ledger timestamps.

Conversely, the current repository's `20260913090000_pre_confirmation_order_editing.sql` defines `update_order`, and the staging function inventory does **not** contain `update_order`. This is direct evidence that the staging state is a mixed/partial implementation relative to current `main` rather than a simple old snapshot.

### 3. Invoice lineage is a clear schema-level delta

Current `main` defines `invoice_template_versions` in `20260914010000_invoice_template_version_lineage.sql`. The staging public table inventory contains no `invoice_template_versions` table. This is a confirmed object-level difference, not a migration-ID naming issue.

### 4. Constraint-level drift is already visible

Staging contains duplicate logical checks/unique constraints in at least the `orders` and `invoice_records` areas (for example the duplicated AED/original-amount checks and duplicated invoice-number uniqueness). This reinforces the requirement to compare exact constraint definitions rather than only object existence.

## Reconciliation status model

Use these statuses for every object/dimension:

- **MATCHED** — staging definition is equivalent to the current repository's intended definition.
- **MISSING** — current repository requires an object not present in staging.
- **DRIFTED** — object exists but definition differs.
- **EXTRA/LEGACY** — staging contains an object not required by current repository, requiring provenance review before removal.
- **UNVERIFIED** — source definition or live evidence is insufficient.
- **NOT APPLICABLE** — dimension genuinely does not apply.

## Required deep-diff procedure

1. Capture staging definitions from `pg_catalog` / `information_schema` for all 18 tables, constraints, indexes, policies, triggers, functions, sequences and grants.
2. Derive the intended current-repository schema from the full ordered migration set on a disposable clean database, without touching staging or production.
3. Compare normalized definitions, not names alone. Normalize whitespace and PostgreSQL-generated naming where appropriate, but retain semantic differences.
4. Produce a per-object diff with source migration and evidence.
5. Resolve every `MISSING`, `DRIFTED`, and `EXTRA/LEGACY` item.
6. Rebuild from the canonical path and run the full database test suite.
7. Only then define the production forward-migration sequence.

## Safety gate

No production DDL and no staging reset should occur as part of this mapping exercise. The goal is to **prove** the forward path before executing it.
