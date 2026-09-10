# Lifecycle and Financial Contract — v4.0

## Order lifecycle

```text
Draft → Confirmed → Active → Completed
  └──────────────→ Cancelled
```

- `Draft → Confirmed`: explicit confirmation command.
- `Draft → Cancelled`: permitted cancellation.
- `Confirmed → Active`: system transition once a parcel reaches Dispatched or later.
- `Confirmed → Cancelled`: permitted only when no parcel has reached Dispatched or later.
- `Active → Completed`: all parcels are terminal and required COD/financial exceptions are resolved/closed.
- There is no generic Admin cancellation override.

## Parcel lifecycle

```text
Prepared → Dispatched → In Transit → Delivered
                         └──────────→ NDR → In Transit
                                      └────→ RTO
                         ├──────────→ RTO
                         ├──────────→ Lost
                         └──────────→ Damaged
```

- Cancellation is only available to an eligible Prepared parcel.
- Parcel state is authoritative for current physical status.
- Delivery outcomes are immutable history.
- NDR is non-terminal.
- Terminal physical outcomes are not normally reversed; exceptional corrections are separate controlled commands.

## Allocation contract

- `parcel_items` records exact integer quantities allocated from `order_items`.
- An order item can be split across parcels.
- Active allocation cannot exceed ordered quantity.
- Allocation reversal/release retains historical evidence rather than deleting prior records.
- Delivered + RTO + Lost + Damaged cannot exceed ordered quantity.

## Financial contract

- `orders.original_amount` is the single manually entered Total Order Amount.
- All monetary values use `NUMERIC(12,2)`.
- No service fee, discount, VAT, unit price or order-item monetary amount exists in v4 MVP.
- Original amount is immutable after confirmation.
- Effective amount is original amount plus the sum of append-only financial adjustment deltas.
- Financial adjustments record the reason, actor, time and optional order/parcel/COD reference.
- No adjustment overwrites historical monetary values.

## COD contract

- The order owns the expected COD obligation.
- Parcel expected COD allocations must reconcile to the order obligation.
- Each parcel has zero or one COD receipt.
- `UNIQUE(parcel_id)` prevents duplicate receipt creation.
- Receipt stores expected snapshot and received amount.
- Any non-zero variance is `Exception` and remains immutable.
- `resolve_cod_exception` is Admin-only and creates an auditable resolution/adjustment.
