# Financial Integrity and Concurrency Review

**Audit item:** AUD-P1-008  
**Scope:** Static review of selected COD receipt, allocation, financial adjustment, idempotency, and reconciliation migrations on `main`.  
**Reviewed files:**  
- `20260911130000_command_idempotency.sql`
- `20260918180000_cod_allocation_sum_invariant.sql`
- `20260918240000_cod_receipt_immutability.sql`
- `20260918250000_financial_adjustment_command.sql`
- `20260918290000_cod_financial_reconciliation.sql`
- `20260929050000_p15_t236_cod_receipt_ambiguity_hardening.sql`

**Execution boundary:** Read-only source review. No SQL executed, no database accessed, no transactions simulated, no code changed, no deployment performed.

## Executive summary

The reviewed financial path contains several meaningful controls: COD receipts are immutable after recording, receipt recording uses an idempotency claim and locks the obligation/parcel/allocation rows, financial adjustments are append-only and admin-gated, and a trigger enforces allocation totals against the COD obligation.

Two areas warrant focused verification before relying on reconciliation outputs for operational or financial decisions:

1. The reconciliation function calculates receipt variance but its state classification does not directly use a non-zero variance, and it does not explicitly compare the COD expected amount with the effective order amount.
2. The allocation-sum trigger locks the obligation row, but the static review alone does not prove every concurrent allocation write path obtains a compatible lock before its insert/update/delete. Concurrency behavior must be tested with controlled parallel transactions, not inferred from the trigger comment.

This review is not a finding that financial records are currently incorrect. It identifies code-level behavior and tests needed to establish correctness.

## Controls observed

### COD receipt recording

The reviewed `record_cod_receipt` function:

- Requires an authenticated operational role and a non-empty idempotency key.
- Claims idempotency using command name, key, and a hash of obligation ID, parcel ID, and received amount.
- Locks the COD obligation, parcel, allocation, and any existing receipt rows with `FOR UPDATE`.
- Requires the parcel to belong to the obligation’s order, rejects cancelled parcels and closed/voided obligations, and uses the allocation as the expected-amount source.
- Returns the prior receipt for a matching existing parcel receipt when obligation, snapshot amount, and received amount match; otherwise it raises a duplicate-receipt error.
- Writes receipt, event, audit log, and completed idempotency result in the same function transaction.
- Uses a unique receipt-per-parcel hardening migration elsewhere in the migration chain; the reviewed function also queries by parcel ID.

### Append-only corrections

The reviewed `create_financial_adjustment` function:

- Requires admin role, order ID, trimmed type/reason, amount, and idempotency key.
- Claims idempotency and returns the prior result for a completed matching request.
- Locks the order and any supplied parcel/receipt; validates parcel and receipt ownership against the order.
- Inserts a new adjustment row, writes an order event and audit log, then completes idempotency.
- Treats corrections as new adjustment entries rather than editing immutable receipts.

The receipt immutability migration adds a trigger rejecting receipt updates/deletes and revokes direct table-level mutation privileges from application roles.

### Allocation invariant

The reviewed `enforce_cod_allocation_sum_invariant` trigger function locks the relevant obligation row and sums parcel allocation amounts. It rejects allocation totals above the obligation and requires exact equality before an obligation can be marked `Received` or `Closed`.

The trigger is a useful guard, but the actual race behavior depends on all write paths and database transaction/locking semantics. The source comment states the intent; it is not proof that every concurrency interleaving is covered.

## Findings

| ID | Finding | Risk | Evidence / limitation |
|---|---|---|---|
| FIN-01 | Reconciliation computes receipt variance but does not directly use a non-zero variance to classify the reconciliation state. | Medium | `get_cod_financial_reconciliation` calculates `v_receipt_variance`, returns it, and classifies using exception count, unreceived allocations, allocation total, and received-vs-effective totals. A variance can be returned while the state is determined by other conditions. Needs business-rule confirmation. |
| FIN-02 | Reconciliation does not explicitly assert that COD expected amount equals effective order amount before reporting `Reconciled`. | Medium–High | The function computes `v_effective` from original amount plus adjustments and separately computes `v_cod_expected`; the state checks allocation total against COD expected and receipts against effective amount, but no direct `v_cod_expected <> v_effective` condition appears in the reviewed function. |
| FIN-03 | Allocation trigger concurrency guarantee needs a multi-session test of every mutation path. | High until verified | Trigger locks the obligation row and sums allocations. Static source review cannot establish all concurrent interleavings or confirm that all paths serialize on the same parent row. |
| FIN-04 | Idempotency safety depends on request-key reuse and command implementation remaining consistent. | Medium | Unique key scope is actor + command + key; request hash mismatch raises an error; completed requests return stored results. The reviewed claim function permits an existing `Started` claim to return `is_new = true`, so transaction rollback/exception behavior and any future multi-transaction command changes deserve explicit tests. |
| FIN-05 | Financial adjustment amount validation is not fully characterized by the selected source excerpts. | Low–Medium | The command rejects null amounts and validates the resulting amount through a separate migration. This review did not inspect every downstream constraint or every financial command, so do not infer a complete accounting policy from these files alone. |

## Recommended acceptance tests

These tests should be run only against an isolated disposable test database or in a separately approved staging test window. They were **not** run for this audit.

1. **Reconciliation amount mismatch:** Create isolated test data where effective order amount differs from COD obligation amount, with allocations equal to the obligation and receipts equal to effective amount. Confirm the returned state cannot incorrectly imply full financial reconciliation.
2. **Receipt variance:** Test under-collection, exact collection, over-collection, and exception-state receipts. Confirm the state, variance, outstanding amount, and exception count jointly express the intended business outcome.
3. **Concurrent allocation attempts:** Two independent sessions attempt allocations that together exceed the obligation. Verify no committed outcome exceeds the allowed total.
4. **Concurrent receipt attempts:** Two sessions record a receipt for the same parcel using different idempotency keys. Verify only one receipt is committed and the losing request receives a deterministic error.
5. **Idempotent retry:** Repeat the same receipt/adjustment request with the same actor, command, key, and payload. Verify the same result is returned without duplicate financial rows.
6. **Idempotency key collision:** Reuse a key with a different payload. Verify a hard failure and no second financial mutation.
7. **Rollback on audit/event failure:** Inject a controlled failure in an isolated test so event or audit writing fails. Verify the financial mutation and idempotency completion roll back together.
8. **Receipt immutability:** Attempt update/delete as each relevant application role. Confirm rejection and verify supported corrections are appended as adjustments.
9. **Adjustment ownership:** Supply a parcel or receipt belonging to another order. Verify rejection and no adjustment/event/audit mutation.
10. **Property-based totals:** For generated multi-parcel cases, check allocation sums, receipt sums, adjustment totals, and reconciliation outputs against an independently calculated expected result.

## Recommendations

- Confirm the business definition of `Reconciled`: whether it requires effective amount, COD obligation amount, allocation total, received total, and zero unresolved variance all to agree.
- Make reconciliation state logic explicit for amount mismatches and non-zero variance, if required by that definition.
- Keep the database invariant as the final enforcement layer; validate the full concurrency behavior using independent sessions.
- Preserve the idempotency contract across retries: same request returns the same result; same key with a different request fails; any failed financial command leaves no partial financial/event/audit state.
- Continue to treat original receipts as immutable and use audited append-only adjustments for corrections.
- Review reconciliation outputs against independently computed totals before using them for settlement or financial reporting.

## Limitations and out of scope

- This is a targeted review of selected migrations, not a full audit of every financial SQL function, constraint, trigger, or application caller.
- No database state, live financial records, locks, or transaction schedules were inspected.
- No concurrency or regression tests were run.
- No code, migration, test, workflow, or schema was modified.
- No production or staging database was accessed, reset, repaired, or changed.

## Recommendation

Mark the static review complete and remediation/test evidence pending. Prioritize FIN-01 and FIN-02 as reconciliation correctness questions, then prove FIN-03 with parallel-session tests before making claims about concurrency safety. Any implementation should be a separate approved change and must not alter production schema or data without explicit authorization.
