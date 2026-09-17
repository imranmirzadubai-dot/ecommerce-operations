# Staging Invoice Data Compatibility — 2026-09-17

## Purpose

Record live staging checks required before applying the current repository's invoice template lineage and historical snapshot contract.

## Verified staging results

Project: `ecommerce-operations-staging` (`mijbpvgxrxjaalimyqgm`).

The live `public.invoice_records` table currently contains **0 rows**.

Therefore, the following checks returned zero violations:

- invoice records without a customer: `0`
- invoice records whose order has anything other than exactly one parcel: `0`
- invoice records with null `invoice_number`: `0`
- invoice records with null `template_version`: `0`
- existing `source_snapshot` values: not applicable because the column does not yet exist and there are no invoice rows
- distinct existing `template_version` values requiring registration: none

## Consequence for forward reconciliation

The historical snapshot backfill is currently vacuous on staging because there are no invoice records to preserve. Likewise, the template-version FK has no existing staging invoice values that require historical registration.

This does **not** by itself prove that the invoice lineage migration is safe to execute. The target migration still has to be validated against the complete clean-main dependency graph, including `invoice_template_versions`, `invoice_print_events`, `source_snapshot`, foreign keys, triggers, RLS policies, grants, and the exact invoice-generation command path.

The repository's historical snapshot migration must remain fail-closed: it explicitly refuses to invent historical values when required source data is unavailable.

## Safety status

- No staging DDL executed.
- No production DDL executed.
- No data modified.
- No migration ledger modified.
- Result is evidence for the forward-migration planning gate only.

## Next gate

Complete the remaining object-level dependency comparison and construct the candidate forward migration on a disposable database. Require a zero-unexplained-diff result before any staging application and a separate production-readiness review afterward.
