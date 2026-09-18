# P12-T186 — Implement source-column mapping

## Scope

Implement the Historical Migration source-column mapping step after file staging. The authoritative database command maps retained source JSON columns into `import_rows.normalized_data` and advances the staged batch from `Uploaded` to `Mapping`.

## Verification contract

- `map_import_columns` is the authoritative database command for source-column mapping.
- Only authenticated users can execute the function entry point, and the command enforces the Admin role server-side.
- The function uses a fixed `pg_catalog, public` search path.
- Mapping input must be a non-empty JSON object with non-empty source and target names.
- Canonical target names must be unique.
- The batch must belong to the authenticated initiator and must still be `Uploaded` before mapping.
- Source values are copied from retained `raw_data` into `normalized_data` using the supplied source-to-target mapping.
- Missing source keys remain absent from `normalized_data` for later validation.
- Mapping sets staged rows to `Pending` and advances the batch to `Mapping`.
- Existing command idempotency is used for safe retries.

## Test

`supabase/tests/database/105_source_column_mapping.sql` contains 10 pgTAP assertions covering existence, security, validation, normalized-data mapping, lifecycle transition, and idempotency.

## Dedicated CI

`.github/workflows/p12-t186-source-column-mapping.yml` runs Supabase reset plus the dedicated regression test on pull requests targeting `main`.

No production business data is changed by this milestone.
