# Forward Migration Candidate — 2026-09-17

## Purpose

This document converts the verified staging-vs-clean-main schema differences into a **forward-only migration plan**. It is a planning/reconciliation artifact, not an instruction to execute against staging or production.

## Verified target

The target is the schema produced by the current repository migration chain on a clean database. The clean-main artifact contains 20 public application tables, 35 public functions, 20 RLS policies and 38 non-constraint indexes. The live staging environment currently contains 18 tables, 15 public functions, 17 RLS policies and 34 non-constraint indexes.

## Migration sequence

### Phase A — Preconditions / inventory

1. Capture a fresh staging catalog snapshot immediately before any migration.
2. Verify row counts and duplicate groups for every target UNIQUE/PK boundary.
3. Verify every existing `invoice_records` row has an order, customer and exactly one parcel before historical snapshot backfill.
4. Verify every existing `invoice_records.template_version` value can be registered in the controlled template-version lineage before adding the FK.
5. Verify no existing data violates current-main CHECK constraints.
6. Abort on any unresolved incompatibility; do not coerce or silently rewrite business history.

### Phase B — Additive schema

1. Add `invoice_template_versions` with its checks and self-reference.
2. Register historical template versions required by existing invoice records; baseline `v1.0` may be inserted only where compatible with the repository contract.
3. Add `invoice_records.source_snapshot` as nullable initially.
4. Add `invoice_print_events` and its foreign keys/indexes only after template lineage exists.
5. Add missing current-main indexes that do not change data semantics.

### Phase C — Historical invoice compatibility

1. Populate `source_snapshot` from authoritative order/customer/item/parcel data using the same rules as the repository migration.
2. Require exactly one parcel and an existing customer for every invoice being backfilled.
3. Verify every populated snapshot is a JSON object and contains the required historical fields.
4. Only after a complete verification may `source_snapshot` become `NOT NULL` and receive its object CHECK constraint.
5. Install the immutable snapshot trigger.

The repository's current snapshot migration explicitly fails rather than inventing historical values when an invoice lacks the required source data. This behavior must be preserved.

### Phase D — Command/helper layer

Apply missing command/helper functions in dependency order, after their prerequisite tables/functions exist:

- phone normalization and customer resolution
- profile creation/activation controls
- parcel creation/allocation and allocation invariant helpers
- order editing (`update_order`)
- invoice print command and historical snapshot helpers
- remaining current-main command authorization/integrity helpers

Each command must retain the repository's SECURITY DEFINER, search_path, authorization, idempotency and grant boundaries.

### Phase E — Constraints / corrective items

#### Safe to add after data validation

- current-main composite parcel-item allocation uniqueness boundary
- missing current-main unique/index boundaries
- missing current-main CHECK constraints where existing data passes validation

#### Requires explicit corrective review

- duplicate `orders` AED checks
- duplicate `orders` original-amount checks
- duplicate `invoice_records` invoice-number uniqueness constraints/indexes

Do **not** drop duplicate logical constraints merely because they are redundant. First establish which historical migration introduced each object and whether any application/test contract references its exact name. Removal should be a separate, explicitly reviewed corrective migration after the forward target is otherwise proven.

### Phase F — RLS and grants

1. Enable RLS on the two invoice lineage tables.
2. Add the two missing invoice SELECT policies.
3. Add `profiles_admin_select` only after confirming its intended locked policy contract.
4. Reconcile table privileges so browser roles retain read-only access and state-changing operations remain command-mediated.
5. Verify function EXECUTE privileges independently from table RLS.

The repository's RLS migration explicitly revokes browser INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER privileges and grants controlled SELECT access; this boundary must remain intact.

### Phase G — Verification gate

A migration candidate is not deployable until all of the following pass on a disposable database rebuilt from the candidate path:

- schema object inventory comparison;
- column/type/default/nullability comparison;
- PK/FK/UNIQUE/CHECK comparison;
- index comparison, including partial/functional indexes;
- RLS enabled-state and policy comparison;
- trigger comparison;
- function definition/security/search_path comparison;
- role/table/function privilege comparison;
- existing staging-data compatibility tests;
- complete database regression suite;
- clean rebuild from zero;
- second independent schema diff showing zero unexplained differences.

## Current blockers

1. Historical provenance for the 33 staging migration IDs is still incomplete.
2. A literal remote `pg_dump`/migra comparison has not been performed because the available execution environment does not expose the staging database password and does not have those binaries installed.
3. The exact historical `template_version` values and invoice data compatibility must be checked before applying the invoice lineage FK/snapshot contract.
4. Duplicate staging constraints remain unresolved and must not be removed speculatively.
5. Production migration has not been authorized by evidence: production currently lacks independently verified migration/RLS deployment evidence.

## Explicit non-actions

- No staging reset.
- No production DDL.
- No fake entries in `supabase_migrations`.
- No migration renaming solely to match historical IDs.
- No destructive constraint/index drops in the first forward migration.
- No invented historical invoice snapshots.

## Decision

The correct implementation path is **forward reconciliation from the verified staging state toward the current repository contract**, with additive/data-safe changes first and corrective cleanup separated. The first executable migration must be generated only after the invoice-version/data compatibility checks and complete dependency inventory are captured.
