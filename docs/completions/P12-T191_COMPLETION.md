# P12-T191 — Import Preview Create/Update/Error Counts

## Scope
Implemented a read-only staging preview command for customer import outcomes.

## Command
`public.preview_import_customer_changes(uuid, text)`

Returns:
- `batch_id`
- `row_count`
- `create_count`
- `update_count`
- `error_count`

## Classification
- `Create` rows are counted as creates.
- `Matched` rows are counted as updates for preview purposes.
- `Error` and `Exception` rows are counted as errors.

## Controls
- SECURITY DEFINER with fixed `search_path = pg_catalog, public`.
- Authenticated actor required and Admin role enforced.
- Batch ownership is enforced through `initiated_by`.
- Preview does not create or update production customer data.
- Preview does not mutate staged rows.
- Command idempotency is retained for deterministic retries.
- Anonymous execution is revoked; authenticated execution remains for server-side role gating.

## Verification
Static pgTAP regression coverage contains 10 assertions. Dedicated CI resets the database and executes `110_import_preview_counts.sql`.

No production business data changed.
