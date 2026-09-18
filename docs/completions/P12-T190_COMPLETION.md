# P12-T190 Completion — Customer Matching and Exception Handling

## Scope
Implement deterministic customer matching for staged historical-import rows and classify rows for later production import.

## Implementation
- Added `import_rows.matched_customer_id` with a foreign key to `customers`.
- Added `customer_match_status`, `customer_match_method`, and `customer_match_error` fields.
- Added indexes for matched customer and match status.
- Added `public.match_import_customers(uuid, text, text)` as an authoritative SECURITY DEFINER command.
- Exact matching uses the normalized phone already produced during the import normalization stage.
- Existing customers are classified as `Matched` and receive `matched_customer_id`.
- Valid rows with no existing customer are classified as `Create` for the later production-import stage.
- Missing/invalid normalized phones are classified as `Exception`, retain an explicit error, and move the row to `Error`.
- Existing customer records are not created or updated by this staging command.
- Batch remains `Ready` when there are no matching exceptions; otherwise it remains `Validating`.
- Command idempotency is used for safe retries.
- Anonymous execution is revoked; authenticated execution remains behind the server-side Admin role gate.
- Fixed `search_path = pg_catalog, public`.

## Verification
- Dedicated T190 database regression workflow.
- 10 static pgTAP assertions covering schema, command security, grants, matching classifications, and idempotency.
- No production business data changed.

## Deferred
Customer creation/update execution, preview counts, reconciliation, and production import remain later P12 milestones.
