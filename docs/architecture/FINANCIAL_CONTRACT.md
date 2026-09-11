# Financial Contract — v4.0

## Monetary model

- `orders.original_amount` is the single manually entered Total Order Amount for the order.
- Currency is explicitly stored as `currency_code` and the MVP permits `AED` only.
- Monetary values use PostgreSQL `NUMERIC(12,2)`; application code must not use binary floating-point arithmetic for persisted monetary values.
- Amounts are represented and persisted to exactly two decimal places.
- No service fee, discount, VAT, unit price, tax engine, or order-item monetary amount exists in the MVP.

## Original amount

- `original_amount` is required and must be non-negative.
- It is the authoritative commercial amount captured at order entry.
- It may be changed while the order is Draft through the appropriate transactional command.
- Once the order is Confirmed, `original_amount` is immutable.
- Later operational or financial corrections must never overwrite the original amount.

## Effective amount

The effective commercial amount at any point is:

`effective_amount = original_amount + SUM(financial_adjustments.delta_amount)`

If there are no adjustments, the sum is zero and effective amount equals original amount.

- Positive `delta_amount` increases the effective amount.
- Negative `delta_amount` decreases the effective amount.
- Zero-value adjustments are not meaningful financial corrections and should not be created.
- Arithmetic is performed in exact decimal/numeric form and must remain at two-decimal precision.
- The calculation is deterministic from the immutable original amount plus the append-only adjustment ledger.

## Adjustment ledger

`financial_adjustments` is append-only business history.

Every adjustment records:

- order ID
- adjustment type
- signed delta amount
- mandatory reason
- actor
- timestamp
- optional parcel reference
- optional COD receipt reference

An adjustment is a new financial event. It does not mutate, replace, or delete a previous adjustment or the original order amount.

Financial adjustments are restricted to the authorized Admin command path. UI visibility is not an authorization boundary.

## Rounding and precision

- No intermediate currency calculation may silently round to whole currency units.
- Since the MVP has no percentage/tax/fee engine, there is no proportional calculation that requires a separate rounding algorithm.
- Inputs outside two-decimal currency precision must be rejected or normalized explicitly at the command boundary; the database remains the final precision constraint.
- Reports and exports must derive amounts from the same authoritative numeric values and adjustment aggregation used by the application, not from independently recomputed UI totals.

## Lifecycle interaction

- Cancellation does not erase financial history.
- A cancelled order remains queryable with its original amount and any valid historical adjustments.
- Delivery/RTO/Lost/Damaged outcomes do not silently alter the original amount.
- A delivered-amount discrepancy is represented by an explicit financial adjustment, with reason and audit evidence, rather than overwriting historical values.
- COD variance resolution may create an auditable financial adjustment where the business rule requires it; the receipt itself remains immutable.

## Authorization and atomicity

Financial adjustment commands must validate authentication, Admin authorization, target existence, input precision/range and relevant lifecycle conditions before writing. The adjustment, associated audit record and required domain event must commit atomically or all roll back.

No browser-calculated amount is authoritative. The server/database is the source of truth.

## Examples

- Original AED 250.00, no adjustments → effective AED 250.00.
- Original AED 250.00, adjustment `+10.00` → effective AED 260.00.
- Original AED 250.00, adjustments `-20.00` and `+5.00` → effective AED 235.00.
- Original AED 250.00, adjustment `-250.00` → effective AED 0.00.

These examples illustrate arithmetic only; they do not grant permission to create an adjustment or bypass lifecycle rules.

## Audit requirements

Each adjustment must remain traceable to its actor, reason, timestamp and affected order, with optional parcel/COD linkage. Historical financial records are not hard-deleted through normal application access.
