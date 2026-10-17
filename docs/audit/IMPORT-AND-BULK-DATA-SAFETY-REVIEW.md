# Import and Bulk-Data Safety Review

**Audit item:** AUD-P1-009  
**Scope:** Static review of selected historical import staging, validation, reconciliation, error reporting, and production-import SQL functions on `main`.  
**Reviewed files:** `20260919010000_import_file_staging.sql`, `20260919030000_import_row_validation.sql`, `20260919070000_import_staging_reconciliation.sql`, `20260919080000_import_monetary_count_reconciliation.sql`, `20260919090000_import_production_idempotent.sql`, `20260919110000_import_error_reports.sql`, and `20260930050000_p15_t239_import_runtime_hardening.sql`.

**Execution boundary:** Source-only review. No SQL executed, no database accessed, no file uploaded, no import run, and no application, migration, workflow, or schema modified.

## Executive summary

The import design has several sound controls: staging is admin-only and idempotent; source rows retain raw data; validation records row errors; customer matching and reconciliation are separate stages; production import requires a Ready batch plus staging and monetary/count reconciliation; and production import creates each order and its item inside one database function transaction. The import error report preserves source-row lineage.

The most important review question is whether the production import revalidates that a row classified as `Matched` still refers to the intended customer. In the reviewed function, a matched row's `matched_customer_id` is required to be non-null, but the function does not visibly re-check that customer's normalized phone against the current row's phone before creating the order. This should be tested and, if the contract requires it, guarded before the import is relied upon for large or financially consequential batches.

This is a static source observation, not evidence of incorrect customer linkage in existing records.

## Observed import lifecycle

1. **Stage:** `stage_import_file` requires an admin, non-empty source-system/file labels, a non-empty JSON array, and an idempotency key. It stores each object in `import_rows.raw_data` and creates one batch. Non-object elements cause a row-count mismatch exception.
2. **Map and validate:** `validate_import_rows` validates configuration shape and field types, checks the batch belongs to the caller and is in the Mapping state, and records row-level status/errors while retaining raw and normalized data.
3. **Normalize and classify:** Separate functions normalize phone fields and classify customer matches; the staging reconciliation checks row classifications and status consistency.
4. **Reconcile:** `reconcile_import_monetary_counts` compares total staged rows and amount totals with caller-supplied control totals, and stores the reconciliation result on the batch.
5. **Production import:** `import_historical_batch` requires an admin, a Ready batch owned by the caller, and both staging and monetary/count reconciliation flags to be true. It then creates/reuses customers and creates one historical order plus one order item per staged row.
6. **Error report:** `generate_import_error_report` returns error rows with source row number, source record ID, source identity, and error text.

## Findings

| ID | Finding | Risk | Evidence / limitation |
|---|---|---|---|
| IMP-01 | Production import trusts a row's existing `Matched` classification and non-null customer ID without visibly revalidating that customer's phone against the current normalized row phone. | High until verified | In `import_historical_batch`, the Matched branch assigns `r.matched_customer_id` and checks only for null before order creation. No comparison to `v_phone` is visible in that branch. |
| IMP-02 | Monetary/count reconciliation proves row count and total amount match the supplied controls, but those totals alone cannot prove row-by-row correctness or prevent offsetting errors. | Medium | The function compares total rows and sum of a selected amount field against caller-supplied expected totals. Independent source control provenance and per-row identity checks are outside this function. |
| IMP-03 | Import creates one order and one order item for each staged row; source files where one order spans multiple item rows need explicit mapping/contract confirmation. | Medium | The production import function comments and implementation model one staged source row as one historical order/item record. |
| IMP-04 | The import workflow is transactional within the database function, but file staging, mapping, validation, reconciliation, and production import are separate commands. | Medium | Each stage is a distinct function call. A failed command should roll back its own transaction, but earlier successful stages remain stored. |
| IMP-05 | Idempotency prevents duplicate batch/command execution for matching keys and payloads, but operators still need a controlled new-key/retry policy after corrected source data or changed mappings. | Medium | The reviewed functions hash request parameters and return completed results for reused matching keys; changed requests under the same key are rejected by the shared idempotency contract. |

## Controls observed

- **Authorization:** The reviewed staging and production import functions require admin role; batch access is tied to the initiating actor.
- **Input shape:** Staging requires a JSON array with at least one row; validation configuration is checked for expected JSON types and supported declared types.
- **Data preservation:** Raw source data is retained; validation and phone normalization update staged status/normalized values rather than rewriting the raw source.
- **Readiness gate:** Production import requires `Ready` and both staging and monetary/count reconciliation flags.
- **Row-level gate:** Production import rejects batches containing rows not marked Valid or not classified Matched/Create.
- **Canonical value checks:** The import checks name, phone format, item description, positive quantity, and non-negative amount before creating records.
- **Conflict handling:** For rows marked Create, customer creation uses `ON CONFLICT (normalized_phone) DO NOTHING` and reuses the existing customer if another row/session created that phone first.
- **Lineage:** Each created order includes a source-row note and an order event with batch ID, source row number, source record ID, and source identity.
- **Error visibility:** A dedicated admin-only report exposes retained row errors and source-row identifiers.

## Recommended acceptance tests

Run only against an isolated disposable test database or a separately approved staging test window. None were run for this audit item.

1. **Stale customer match:** Mark a row Matched to customer A, then change the row's normalized phone to customer B's phone before import. Confirm import rejects the stale association or re-matches according to the intended contract.
2. **Deleted/missing matched customer:** Make the referenced customer unavailable in an isolated fixture. Confirm a clear failure and no partial production records.
3. **Same-phone concurrent create:** Two rows/sessions attempt to create the same normalized phone. Confirm uniqueness is preserved and order-to-customer links are deterministic.
4. **Idempotent staging retry:** Repeat the exact stage request with the same actor/key/payload. Confirm one batch and one source-row set.
5. **Changed payload under same key:** Reuse a staging/import key with changed input. Confirm rejection rather than silent reuse of the old result.
6. **Validation failure:** Include mixed valid/invalid rows. Confirm errors remain attached to source rows and production import refuses the batch until its state and classification satisfy the gate.
7. **Control-total mismatch:** Alter expected row count or amount by a small amount. Confirm reconciliation is false and production import is blocked.
8. **Offsetting monetary errors:** Two row amounts are wrong in opposite directions while the grand total remains unchanged. Confirm additional row-level/source-identity checks detect the errors where required.
9. **Import mid-batch failure:** Inject a controlled constraint failure on a later row. Confirm the production import transaction leaves no partial customer/order/item/event set from that failed call and the batch/idempotency status is recoverable.
10. **Lineage completeness:** Verify each created order can be traced to exactly one batch/source row and error reports preserve source-row identity.
11. **Large batch limits:** Exercise the approved maximum row/file size, request payload size, execution duration, and memory limits without production data.
12. **Duplicate source rows:** Test repeated source IDs/identities and confirm the documented policy is either reject, deduplicate, or import separately.

## Recommendations

- Before production import, verify that each Matched row's referenced customer still exists and matches the canonical normalized phone, or re-run matching under a locked/controlled batch state.
- Document the source file contract: whether one row means one order, one item, or one customer/order pair; reject unsupported multi-line-order files instead of assuming their meaning.
- Treat reconciliation totals as necessary but not sufficient. Preserve source control totals and add row-level duplicate/identity checks where the source system supports them.
- Define a retry/runbook for failed batches, corrected mappings, and corrected source files. Avoid deleting staging history merely to make a retry pass.
- Set and enforce maximum batch sizes, request payload limits, and execution time budgets; test the largest supported import.
- Ensure audit logs can correlate batch ID, source row identity, created order/customer IDs, operator, and final batch status without exposing sensitive raw data unnecessarily.
- Keep production import explicitly admin-gated and never use a database reset as an import recovery strategy.

## Limitations and out of scope

- Targeted review only; not every import function, table constraint, UI upload path, or Worker route was inspected.
- No real or synthetic batch was executed.
- No database records, schema, or secrets were accessed.
- No claim that all file types, encodings, payload sizes, or multi-line order formats are supported.
- No code, migration, test, workflow, schema, or deployment changes were made.

## Recommendation

Mark the static review complete and implementation/test evidence pending. Prioritize IMP-01 before relying on imported customer relationships. Any remediation should be a separate approved PR with isolated test coverage. Production database structure and data must remain untouched unless separately and explicitly authorized.
