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

## Cancellation contract

### Order cancellation

- Any authenticated user may request cancellation when the lifecycle precondition permits it; role does not create an override.
- A Draft order may be cancelled.
- A Confirmed order may be cancelled only while every associated parcel remains before Dispatched.
- An order may not be cancelled once any associated parcel has reached Dispatched or any later physical state.
- Cancellation is a state transition, not deletion. The order, items, customer relationship, events and audit history remain queryable.
- A cancelled order cannot be confirmed, dispatched, completed, or otherwise re-enter the normal forward lifecycle.
- There is no generic Admin override. Exceptional correction is a separate controlled operation with its own authorization and audit evidence.

### Parcel cancellation

- Any authenticated user may cancel an eligible parcel.
- Only a `Prepared` parcel may be cancelled through the normal cancellation command.
- A parcel that has reached `Dispatched` or later cannot be normally cancelled.
- Parcel cancellation preserves the parcel record and history; it does not hard-delete the parcel.

## Reversal and release behavior

- Cancellation must reverse or release any still-reversible operational reservation created by the cancelled object without destroying historical evidence.
- Prepared parcel cancellation releases its active allocation from the order items so the remaining ordered quantity remains available for other valid parcels; the historical allocation/cancellation event remains auditable.
- No allocation may be silently rewritten to make a cancellation appear not to have happened.
- Delivered, RTO, Lost and Damaged quantities are terminal physical outcomes and are not normally reversed.
- Exceptional correction of a terminal physical outcome must use a dedicated controlled correction command, validate the current state and resulting quantities, preserve the original event, record the actor/reason, and create a new corrective event.
- Reversal is therefore an explicit business operation, not a database delete/update shortcut.
- A reversal/correction must never cause delivered + RTO + Lost + Damaged quantities to exceed the original ordered quantity.
- Cancellation/reversal operations are transactional: validation, state/allocation changes, domain event and audit record succeed or fail together.

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
