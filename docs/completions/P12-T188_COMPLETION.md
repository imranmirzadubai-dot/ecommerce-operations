# P12-T188 Completion — Phone normalization during import

## Scope
Implemented deterministic phone normalization for configured staged import fields after source-column mapping and validation.

## Authoritative command
`public.normalize_import_phone_fields(uuid, jsonb, text, text)`

- SECURITY DEFINER with fixed `search_path = pg_catalog, public`.
- Authenticated actor required and `Admin` role enforced server-side.
- Batch ownership is checked against the authenticated initiator.
- Batch must be in `Mapping`, `Validating`, or `Ready` state.
- Configured phone fields must be a non-empty unique JSON array.
- Optional default country code is validated as a 1–3 digit international calling code.
- Supports `+`-prefixed international numbers, `00`-prefixed international numbers, national numbers using the supplied default country code, and already international digit strings.
- Canonical output is `+` followed by 7–15 digits.
- Invalid phone values become row-level `Error` entries rather than being silently accepted.
- `raw_data` remains unchanged; non-phone mapped fields in `normalized_data` are preserved.
- Existing command idempotency is used for safe retries.
- Anonymous execution is revoked; authenticated entry remains for server-side role gating.

## Regression coverage
`supabase/tests/database/107_import_phone_normalization.sql` contains 10 pgTAP assertions covering the function contract, security boundary, search path, authorization, execution grants, country-code handling, canonical formatting, `00` conversion, and invalid-value/error preservation behavior.

## CI
Dedicated workflow: `.github/workflows/p12-t188-phone-normalization.yml`

The workflow resets the Supabase database and executes the T188 pgTAP regression test.

## Boundary
No production business data is changed. Customer matching, deterministic source identity, preview, reconciliation, and production import remain later milestones.
