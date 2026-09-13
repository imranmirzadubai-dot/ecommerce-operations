# Deletion and Retention Policy — T047

## 1. Purpose

This document formalizes deletion, retention, correction, and archival rules for the E-Commerce Operations MVP. It defines which records may be deleted, which are retained as historical evidence, and how corrections must be represented.

This is a Phase 2 architecture contract. It does not silently implement Phase 3 database policies or migrations.

## 2. Core rule

Business history is retained. Cancellation, correction, rollback, and failure are represented as explicit state/evidence transitions rather than destructive deletion of transactional history.

The default for a business record is **retain unless an explicit rule below permits deletion**.

## 3. Retention classes

| Record class | Retention rule | Normal hard delete | Correction model |
|---|---|---:|---|
| `profiles` | Retain while account/history is required; deactivation is preferred to deletion | No | Admin/account command + audit |
| `customers` | Retain when referenced by orders/history | No | Authorized customer command; preserve order history |
| `orders` | Permanent business history for MVP | No | Lifecycle transition / authorized correction |
| `order_items` | Retain with parent order | No | Authorized correction subject to lifecycle rules |
| `parcels` | Retain with shipment history | No | Lifecycle transition |
| `parcel_items` | Retain allocation history | No | Allocation reversal/new allocation evidence |
| `delivery_outcomes` | Append-only operational history | No | New corrective outcome/event |
| `cod_obligations` | Retain with financial history | No | Authorized COD command/exception |
| `cod_obligation_allocations` | Retain reconciliation history | No | New allocation/correction evidence |
| `cod_receipts` | Immutable collection evidence | No | Authorized correction/exception; never overwrite receipt history |
| `financial_adjustments` | Append-only financial evidence | No | New adjustment/reversal |
| `invoice_records` | Retain generated invoice history | No | New version/reissue record where supported |
| `order_events` | Immutable domain history | No | Append a new fact |
| `audit_logs` | Immutable accountability evidence | No | Append a correction/audit event |
| `import_batches` | Retain import lineage and outcome | No after creation | New import/reconciliation batch |
| `import_rows` | Retain raw/normalized import evidence | No after creation | New row/import evidence; do not rewrite prior evidence |

## 4. Allowed deletion

Deletion is limited to records that are explicitly classified as non-business, non-audit, and non-referenced operational artifacts by a later approved implementation contract.

The MVP does not define any ordinary browser-facing hard-delete operation for transactional domain records.

A future deletion capability must establish, before implementation:

1. exact table and record class;
2. legal/business retention requirement;
3. referential-impact analysis;
4. authorization and approval requirement;
5. audit evidence of the deletion;
6. recovery/rollback strategy where feasible;
7. whether anonymization is preferable to deletion.

No implementation may infer permission to delete merely because a row is no longer displayed in the UI.

## 5. Cancellation is not deletion

Order and parcel cancellation changes lifecycle state. It does not remove the order, parcel, items, allocations, events, audit evidence, or financial history needed to explain what happened.

A cancelled record remains addressable by its authoritative UUID and immutable human-readable identifier.

## 6. Historical imports

Import staging is historical lineage. A completed or failed import batch and its rows must remain available for reconciliation and audit according to the retention policy.

A corrected source file creates a new import batch. Prior import evidence is not overwritten to make the new result appear as though it were the original import.

## 7. Personal-data deletion requests

The MVP architecture must distinguish business-record retention from any later privacy/legal deletion or anonymization requirement. A legal/privacy requirement may require a dedicated controlled workflow; it must not be implemented as ad-hoc deletion from individual tables because that can break financial, operational, audit, or referential history.

If such a requirement is introduced, the change must define scope, lawful basis/retention conflict, anonymization strategy, affected relationships, audit treatment, and approval before implementation.

## 8. Referential integrity

Core historical relationships must not be broken by deletion. Foreign keys and application commands are expected to prevent deletion that would orphan authoritative history.

The application must never use cascading deletion as a shortcut for ordinary business cancellation.

## 9. Sequence and identifier interaction

Deletion must never cause customer codes, order numbers, parcel numbers, barcodes, tracking IDs, or invoice numbers to be reused or renumbered.

Sequence gaps remain valid. Historical identifiers remain immutable even when the underlying record reaches a terminal state.

## 10. Audit requirements

Any approved destructive or privacy-controlled action must record, at minimum:

- authenticated actor;
- application role;
- target entity and authoritative ID;
- reason or approved action type;
- timestamp;
- relevant before/after or deletion evidence consistent with privacy requirements;
- request/correlation identifier where available.

Audit evidence itself is retained and is not deleted by the operation it records.

## 11. Security boundary

Deletion and retention operations are privileged commands. They are not direct browser-table writes.

The command must validate authorization, retention eligibility, referential safety, and required approval inside the transaction before mutation. Normal application roles do not receive generic `DELETE` privileges.

## 12. Recovery and rollback

For ordinary business correction, prefer reversible state transitions, compensating records, or new authoritative evidence over physical deletion.

Where a destructive action is genuinely required, the implementation must document whether rollback is possible. A backup restore is not considered an application-level rollback mechanism.

## 13. Required negative properties

- No normal user can hard-delete transactional history.
- Cancellation cannot erase historical evidence.
- Deletion cannot renumber or reuse identifiers.
- Import correction cannot overwrite prior import lineage.
- Audit evidence cannot be removed by the operation it records.
- Foreign-key integrity cannot be bypassed through a deletion shortcut.

## 14. Required positive properties

- Terminal business records remain queryable for operational history.
- Corrections remain traceable to the original record.
- Approved deletion/privacy workflows are explicitly authorized and auditable.
- Retention decisions are deterministic by record class rather than UI visibility.

## 15. Phase 3 implementation mapping

Phase 3 must translate this contract into reproducible database constraints, privileges, commands, and tests covering at minimum:

1. direct `DELETE` denial for normal application roles;
2. terminal-record retention;
3. foreign-key/referential deletion protection;
4. identifier non-reuse;
5. append-only event/audit behavior;
6. import lineage preservation;
7. privileged deletion workflow, if a concrete MVP use case exists;
8. privacy/anonymization workflow, if legally required;
9. audit evidence for every approved destructive operation;
10. rollback/recovery behavior.

## 16. T047 decision

**FORMALIZED — deletion and retention policy established.**

The architecture contract intentionally defines retention and correction behavior without introducing destructive database changes during Phase 2.