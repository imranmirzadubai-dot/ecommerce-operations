# P12-T195 — Historical Import Source Lineage

## Scope
Retain authoritative historical import batch and source-row lineage after production import.

## Implementation
- Added nullable historical-import lineage fields to `public.orders`.
- Added a foreign key from historical order lineage to `public.import_batches` with restrictive deletion semantics.
- Added all-or-none lineage integrity validation and unique batch/source-row protection.
- Added a source-identity lookup index.
- Added an immutable-event-driven SECURITY DEFINER trigger that validates `Historical Import` event metadata against the retained staged source row.
- The trigger persists batch ID, source row number, source record ID, and deterministic source identity on the production order.
- The corresponding staged row is marked `Imported` only after lineage validation succeeds.
- Conflicting pre-existing lineage is rejected.
- No parcel allocation was added.

## Verification
The dedicated pgTAP regression is `supabase/tests/database/114_historical_import_lineage.sql` and the dedicated CI workflow is `.github/workflows/p12-t195-historical-import-lineage.yml`.

No production business data is imported or changed by CI.
