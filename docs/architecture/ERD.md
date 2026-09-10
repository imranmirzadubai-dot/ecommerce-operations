# Database ERD — v4.0

The v4.0 database is centered on the commercial Order and physical Parcel models.

```text
profiles
  │
  ├──< customers
  │       └──< orders
  │             ├──< order_items ──< parcel_items >── parcels ──> shippers
  │             ├──< parcels
  │             ├──< order_events
  │             ├──< financial_adjustments
  │             ├──< invoice_records
  │             └──  cod_obligations ──< cod_receipts >── parcels
  │
  └── actors on operational/audit records

parcels ──< delivery_outcomes

import_batches ──< import_rows

audit_logs records security-sensitive changes across the domain.
```

## Authoritative ownership

- `orders`: commercial transaction and immutable original amount after confirmation.
- `order_items`: description and ordered integer quantity.
- `parcels`: authoritative current physical lifecycle state.
- `parcel_items`: exact integer allocation from order items to parcels; allocation history is retained.
- `delivery_outcomes`: immutable delivery-attempt/outcome history; NDR is non-terminal.
- `cod_obligations`: order-level expected COD obligation.
- `cod_receipts`: actual collection against a parcel; maximum one receipt per parcel.
- `financial_adjustments`: append-only monetary deltas.
- `order_events`: immutable operational history.
- `audit_logs`: immutable security/change accountability.
- `import_batches` / `import_rows`: staged historical-ingestion lineage.

## Integrity principles

1. One parcel belongs to exactly one order.
2. An order item may be allocated across multiple parcels.
3. Active allocated quantity cannot exceed ordered quantity.
4. Delivered/RTO/Lost/Damaged quantities are derived from parcel allocations and authoritative parcel state; they are not competing editable counters.
5. Original order amount is immutable after confirmation.
6. Historical transactional records are never hard-deleted.
7. Human-readable identifiers are generated server-side from dedicated sequences and are unique/immutable, not gapless.
8. Timestamps are stored in UTC; business-date rendering uses Asia/Dubai.
