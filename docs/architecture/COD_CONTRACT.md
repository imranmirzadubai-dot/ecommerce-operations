# COD Obligation and Receipt Contract — v4.0

## Ownership

- The order owns exactly one expected COD obligation through `cod_obligations.order_id UNIQUE`.
- `cod_obligations.expected_amount` is the authoritative expected collection amount for the order.
- Parcel-level expected amounts are represented by `cod_obligation_allocations` so an order's COD obligation can be reconciled across multiple parcels.

## Allocation invariant

`SUM(active parcel COD allocations) = cod_obligations.expected_amount` for an obligation that has been fully allocated for collection.

- Each allocation belongs to one COD obligation and one parcel.
- A parcel may have at most one allocation for the same obligation.
- Allocation amounts are non-negative and use `NUMERIC(12,2)`.
- The system must not silently change an expected amount after collection evidence has been recorded.

## Receipt invariant

- A parcel has zero or one COD receipt; `UNIQUE(parcel_id)` is the database enforcement point.
- A receipt belongs to the corresponding COD obligation and parcel.
- `expected_amount_snapshot` preserves the amount against which the collection was evaluated at receipt time.
- `received_amount` is non-negative and stored as `NUMERIC(12,2)`.
- Receipt state is `Received` when received amount exactly equals the expected snapshot; otherwise it is `Exception`.
- A receipt is immutable business history. Corrections are separate controlled operations and do not overwrite the original receipt.

## Variance

`variance = received_amount - expected_amount_snapshot`

- Exact equality produces zero variance and a normal `Received` receipt.
- Any non-zero variance produces `Exception`.
- Both under-collection and over-collection are exceptions; neither is silently rounded away.
- Variance is evaluated using exact numeric arithmetic at two-decimal currency precision.

## Obligation state

The obligation state communicates collection progress:

- `Outstanding`: no receipt has been recorded and collection remains due.
- `Partially Received`: cumulative receipts/approved collection evidence is below the expected obligation where the supported workflow permits partial collection.
- `Received`: the expected obligation has been fully collected without unresolved variance.
- `Exception`: a collection discrepancy requires controlled resolution.
- `Voided`: the obligation has been explicitly voided by an authorized business operation.
- `Closed`: the obligation has completed its required reconciliation lifecycle.

The state is not a substitute for receipt history or financial audit records.

## Resolution

- A non-zero variance remains an exception until explicitly resolved.
- `resolve_cod_exception` is Admin-only.
- Resolution must preserve the original receipt, record the actor/reason, and create any required financial adjustment as a new append-only record.
- Resolution cannot rewrite the original expected snapshot or received amount.

## Concurrency and idempotency

Receipt creation and COD resolution are state-changing commands and must be transactional and idempotent. The command must validate current obligation/parcel state before writing. Concurrent attempts to create a second receipt for the same parcel must fail deterministically through the unique constraint/transactional command path.

## Authorization

Sales and Operations may record an eligible COD receipt through the approved command. Only Admin may resolve a COD exception or make a financial adjustment. Direct browser writes to COD tables are not permitted.

## Audit

COD receipt creation and exception resolution must create the required domain/audit evidence. The receipt itself is operational financial history; `audit_logs` provides accountability for the action and `order_events` records relevant order/parcel history.

## Examples

- Expected AED 100.00, received AED 100.00 → `Received`, variance AED 0.00.
- Expected AED 100.00, received AED 95.00 → `Exception`, variance AED -5.00.
- Expected AED 100.00, received AED 105.00 → `Exception`, variance AED +5.00.

These examples define arithmetic and state interpretation only; authorization and lifecycle preconditions still apply.
