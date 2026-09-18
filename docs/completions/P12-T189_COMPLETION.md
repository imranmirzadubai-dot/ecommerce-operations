# P12-T189 — Deterministic source identity

## Scope
Implement deterministic source identity for staged historical-import rows after mapping/validation.

## Contract
- Authoritative command: `public.assign_import_source_identity(uuid, jsonb, text)`.
- Admin-only, authenticated entry point with fixed `search_path = pg_catalog, public`.
- Batch must belong to the authenticated initiator.
- Batch must be in `Mapping`, `Validating`, or `Ready` state.
- Identity fields are an ordered JSON array of non-empty mapped field names.
- Each row receives a deterministic SHA-256 identity derived from the source system, source file, and configured identity-field values.
- Missing/null identity-field values are represented deterministically; identity generation never mutates `raw_data`.
- Existing `source_record_id` is retained unchanged.
- Idempotent retries return the original batch/count result.
- No production business data is changed.

## Verification
- 10-assertion pgTAP regression test: `108_deterministic_source_identity.sql`.
- Dedicated workflow: `P12-T189 Deterministic Source Identity`.
- General CI must pass before merge.
- PR approval is required before merge.

## Boundary
Customer matching, exception handling, preview counts, reconciliation, production import, and source-lineage reporting remain later milestones.
