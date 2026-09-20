# P13-T206 — Report Export Test Gate

## Scope

Validate the locked dependency-free XLSX export implementation used by the Phase 13 reporting UI.

## Contract covered

- XLSX ZIP local-file, central-directory and end-of-directory signatures.
- Required Open XML package parts and worksheet relationships.
- Workbook and worksheet content types.
- Deterministic worksheet cell references.
- XML escaping for cell values and worksheet names.
- XLSX MIME type and `.xlsx` filename enforcement.
- Safe empty-workbook fallback.
- Excel worksheet-name sanitization and 31-character limit.

## Authority and exclusions

The export contains only data supplied by the report/order UI. This milestone does not add VAT, discount, unit-price, service-fee, or other derived financial fields. It does not mutate business data.

## Validation

The automated contract test is `tests/unit/excel_export.test.mjs`. The general CI gate remains authoritative for lint, TypeScript typecheck, unit tests, build, and isolated local Supabase database tests.
