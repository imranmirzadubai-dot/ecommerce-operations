# P8-T132 — Historical Reprint Consistency

## Outcome
Invoice reprints now render from an immutable generation-time business snapshot stored on `invoice_records.source_snapshot`.

## Controls
- Existing invoice records are backfilled from authoritative order/customer/item/parcel data.
- Snapshot creation fails rather than inventing data when the invoice source is incomplete or has anything other than exactly one parcel.
- New invoice records capture their snapshot atomically at generation through a trusted database trigger.
- Snapshot mutation is blocked after generation.
- The web print workspace reads and renders the stored historical snapshot, while retaining the invoice record's controlled template version lineage.
- Individual and batch printing therefore use the same historical source and deterministic renderer.

## Verification
- Database rebuild verification extended for the snapshot column, capture trigger, immutability trigger, and trusted function.
- Unit contract tests cover snapshot creation, immutability, and renderer use of the historical snapshot.
- No production data changes are made by the UI implementation.
