# Phase 2 Implementation Test Matrix — T050

## Purpose

This matrix converts the locked Phase 2 architecture contracts into implementation-level verification targets for Phase 3 and later. It is a traceability matrix, not a claim that all tests already exist or pass.

## Matrix

| Area | Source contract | Verification target | Primary layer | Severity |
|---|---|---|---|---|
| Lifecycle | Lifecycle/cancellation contract | Illegal transitions rejected; cancellation preconditions enforced | DB command/integration | P0 |
| Cancellation | Cancellation contract | Order/parcel cancellation preserves history and is idempotent | DB command/integration | P0 |
| Financials | Financial contract | Original amount immutable; adjustments append-only; arithmetic reconciles | DB/integration | P0 |
| COD | COD contract | Obligation/receipt allocation invariants hold; exceptions authorized | DB/integration/security | P0 |
| Quantities | Parcel allocation contract | `parcel_items` quantities reconcile to order items; no over-allocation | DB/concurrency | P0 |
| Identifiers | Identifier/sequence contract | DB owns identifiers; uniqueness, immutability, no MAX()+1/reuse | DB/concurrency | P0 |
| Roles | Role/permission matrix | Sales/Operations/Admin capabilities match contract | Security/integration | P0 |
| RLS | RLS policy matrix | Every exposed domain table has intended row visibility; deny-by-default | DB/security | P0 |
| Grants | Grants/privileged functions | Protected commands not executable by anon/public; minimal execute | DB/security | P0 |
| Commands | Command/API schemas | Signatures, validation, return shapes and idempotency match contract | DB/API | P0 |
| Audit/events | Audit/event taxonomy | State-changing commands atomically emit required evidence; history append-only | DB/integration | P0 |
| Imports | Historical import identity | Batch/row identity, replay/conflict behavior, lineage and raw evidence preserved | DB/import | P1 |
| Retention | Deletion/retention policy | Transactional history cannot be hard-deleted; corrections retain evidence | DB/security | P0 |
| Time | UTC/AED/Asia-Dubai rules | Instants survive round trips; UAE business-day boundaries are correct | DB/API/UI | P1 |
| Currency | UTC/AED/Asia-Dubai rules | AED-only MVP and exact decimal arithmetic | DB/API | P0 |
| Observability | Observability ADR | Structured sanitized telemetry, correlation IDs, useful failure metrics | Worker/integration | P1 |

## Cross-cutting negative tests

1. Anonymous caller cannot execute protected state-changing commands.
2. Authenticated user cannot bypass role checks through direct table writes or alternate RPC paths.
3. Client-provided identifiers cannot replace DB-generated authoritative identifiers.
4. Client-provided financial totals cannot replace server-authoritative arithmetic.
5. Illegal lifecycle transitions cannot be forced by stale/replayed requests.
6. Duplicate command submissions do not produce duplicate business state.
7. Audit/event writes cannot be skipped when the associated business mutation commits.
8. Failed transactions leave no partial business state.
9. Historical evidence cannot be overwritten to conceal a correction.
10. Browser/device timezone cannot alter UAE business-date results.
11. Secrets, credentials and unnecessary PII never enter telemetry.

## Concurrency tests

At minimum, race two or more concurrent requests against:

- order confirmation/cancellation;
- parcel allocation/correction;
- COD receipt allocation;
- identifier generation;
- command idempotency claims.

Expected result: one valid authoritative outcome, deterministic rejection/replay of conflicting work, and no invariant violation.

## Traceability requirement

Every Phase 3 implementation task must map its automated/integration tests back to one or more rows in this matrix and to the relevant architecture contract. Test names should include the domain behavior rather than implementation details alone.

## Gate requirement

P2-T051 must review this matrix against the locked architecture set. Any uncovered P0/P1 contract is a gate defect. Adding new business behavior during this review is out of scope; a missing requirement becomes a documented change decision/task.