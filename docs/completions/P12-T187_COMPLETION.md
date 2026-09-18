# P12-T187 — Implement required-field/type/date/amount validation

## Scope
Implemented the next Historical Migration contract step after source-column mapping.

## Delivered
- `public.validate_import_rows(uuid, jsonb, jsonb, jsonb, jsonb, text)` authoritative transactional command.
- SECURITY DEFINER with fixed `search_path = pg_catalog, public`.
- Authenticated Admin-only server-side role gate.
- Required-field presence validation against `import_rows.normalized_data`.
- Declared `text`, `integer`, `number`, `date`, and `boolean` type validation.
- ISO `YYYY-MM-DD` date validation with PostgreSQL input validation.
- Monetary amount validation requiring numeric, non-negative values with at most two decimal places.
- Row-level `Valid` / `Error` status and retained validation error text.
- Batch transition from `Mapping` to `Ready` only when all rows are valid; otherwise `Validating`.
- Existing command idempotency pattern for safe retries.
- Anonymous execution revoked; authenticated entry retained for server-side role gating.
- 10-assertion pgTAP regression coverage.
- Dedicated P12-T187 database CI workflow.

## Boundary
No phone normalization, deterministic identity, matching, preview, reconciliation, production import, or source-lineage redesign is included; those remain subsequent P12 milestones.

No production business data is changed by this milestone.
