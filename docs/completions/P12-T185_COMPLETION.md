# P12-T185 — Implement import file staging

## Scope

Implement the first Historical Migration contract step: stage a source file as an import batch with its parsed source rows retained verbatim in `import_rows.raw_data`.

## Verification contract

- `stage_import_file` is the authoritative database command for staging.
- Only authenticated users can execute the function entry point, and the command enforces the Admin role server-side.
- The function uses a fixed `pg_catalog, public` search path.
- Source system and source file metadata are required.
- Source rows must be a non-empty JSON array of objects.
- A staged batch is created with `Uploaded` status and the authenticated initiator.
- Source rows are retained with deterministic source row numbers, optional source record identity, verbatim raw data, and `Pending` status.
- Command retries use the existing idempotency infrastructure and return the existing batch result.
- Mapping, normalization, validation, preview, reconciliation, and production import remain later Historical Migration milestones.

## Test

`supabase/tests/database/104_import_file_staging.sql` contains 10 pgTAP assertions covering existence, security, validation, batch/row staging, and idempotency contracts.

## Dedicated CI

`.github/workflows/p12-t185-import-file-staging.yml` runs Supabase reset plus the dedicated regression test on pull requests targeting `main`.

No production business data is changed by this milestone.
