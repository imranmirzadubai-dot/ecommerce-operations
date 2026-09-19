# P12-T193 — Monetary/Count Reconciliation

## Scope
Implemented the Historical Migration reconciliation step for source control totals versus staged import data.

## Command
`public.reconcile_import_monetary_counts(uuid, text, integer, numeric, text)`

The Admin-only command accepts the staged batch, mapped monetary field, expected source row count, expected source monetary total, and an idempotency key.

## Reconciliation contract
- Compares staged row count with the supplied source control count.
- Extracts the configured amount from `import_rows.normalized_data`.
- Computes the staged monetary total with PostgreSQL exact `numeric(12,2)` arithmetic.
- Detects missing, blank, malformed, negative, and over-precision monetary values.
- Returns count and amount deltas plus an explicit `reconciled` boolean.
- Reconciliation succeeds only when row count matches, all amounts are valid, and the monetary delta is exactly zero at two-decimal precision.
- Persists the monetary/count result under `import_batches.reconciliation_summary.monetary_count_reconciliation` without replacing the existing T192 staging reconciliation result.

## Controls
- SECURITY DEFINER with fixed `search_path = pg_catalog, public`.
- Authenticated Admin-only server-side role gate.
- Batch ownership enforced through `initiated_by`.
- Only `Validating` or `Ready` batches may be reconciled.
- Anonymous execution is revoked; authenticated execution remains for server-side role gating.
- Command idempotency is used for deterministic retries.
- No production business data is created, updated, or deleted.
- No staged row data is mutated.

## Verification
- 12 static pgTAP assertions cover the command signature, security, grants, count comparison, monetary comparison, invalid-value detection, exact numeric arithmetic, summary persistence, and idempotency.
- Dedicated P12-T193 database CI resets the database and executes the regression file.

## Boundary
This milestone does not perform production import. Production customer creation/update and historical production import remain subsequent P12 milestones.
