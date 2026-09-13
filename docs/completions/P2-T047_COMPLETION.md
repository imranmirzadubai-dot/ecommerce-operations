# P2-T047 Completion Record

## Task

**P2-T047 — Formalize deletion/retention policy**

## Status

**COMPLETE — Phase 2 architecture formalization**

## Branch

`feature/t046-import-identity-rules`

## Evidence commit

`9515ecb255ec463f21fec93398ff701cac45d469`

## TCR

`ECO-TCR-P2-T047-20260912-9515ecb2`

## Deliverables

- `docs/architecture/DELETION_RETENTION_POLICY.md`
- `docs/test-plans/T047_DELETION_RETENTION_TEST_PLAN.md`
- this completion record

## What was formalized

1. Retention is the default for business and historical records.
2. Transactional history is not hard-deleted as an ordinary application operation.
3. Cancellation is a lifecycle transition, not deletion.
4. Audit logs and domain events are immutable historical evidence.
5. Delivery, COD, financial, invoice, parcel, allocation, and import history are retained.
6. Import corrections create new lineage rather than overwriting prior evidence.
7. Identifiers are never reused or renumbered because of deletion/cancellation.
8. Any future destructive/privacy workflow requires explicit scope, authorization, approval, audit, referential analysis, and recovery rules.
9. Deletion is command-mediated; normal application roles do not receive generic DELETE capability.
10. Phase 3 implementation and security tests are explicitly mapped rather than silently introduced here.

## Verification evidence

Staging schema inspection confirmed the existing import lineage baseline includes UUID primary keys and a unique `(batch_id, source_row_number)` import-row key. No staging business data was changed by this task.

The repository already formalizes immutable event/audit history and server-owned identifiers. T047 extends those principles into an explicit deletion/retention contract without changing the live database.

## Scope boundary

No production changes. No staging DDL. No data deletion. No permission revocation. No migration was introduced by T047.

## Decision

**FORMALIZED — deletion and retention policy established.**

Next task: **P2-T048**.