# T044 Command/API Schema Verification Test Plan

## Objective

Verify that command/API contracts are explicit, deterministic, authorization-aware, idempotent where required, and aligned with the locked business/domain contracts.

## Schema tests

- **T044-01** — Verify every browser-facing command has an explicit name, input schema, output schema, authorization boundary, and error categories.
- **T044-02** — Verify generated identifiers are output values and are not caller-supplied creation identifiers.
- **T044-03** — Verify nullable/required fields and numeric/integer constraints match the domain contract.
- **T044-04** — Verify order item input requires non-empty description and positive integer quantity.
- **T044-05** — Verify lifecycle commands accept only the identifiers and control fields defined by their schema.

## Authorization tests

- **T044-06** — Unauthenticated caller cannot invoke protected commands.
- **T044-07** — Sales/Operations/Admin access matches the capability matrix.
- **T044-08** — Operations-only and Admin-only commands reject unauthorized application roles.
- **T044-09** — Cancellation remains available to all three application roles when lifecycle preconditions pass.
- **T044-10** — Admin does not bypass lifecycle or domain invariants.

## Idempotency tests

- **T044-11** — First valid state-changing request executes once and stores a result.
- **T044-12** — Identical retry returns the stored result without creating a second business record.
- **T044-13** — Same actor/command/key with a different request hash is rejected.
- **T044-14** — Different actors do not share idempotency records/results.
- **T044-15** — A failed/incomplete transaction cannot be reported as a completed successful command.

## Transaction/audit tests

- **T044-16** — Successful lifecycle mutation, domain event, audit record, and idempotency completion commit atomically.
- **T044-17** — Business mutation failure does not leave partial command-owned state.
- **T044-18** — API does not report success before database commit.
- **T044-19** — Actor identity is preserved in events/audit records.

## Error contract tests

- **T044-20** — Authentication/authorization errors map to the stable authorization category.
- **T044-21** — Invalid input maps to the stable validation category.
- **T044-22** — Missing business records map to not-found behavior.
- **T044-23** — Invalid lifecycle transitions map to business-rule behavior.
- **T044-24** — Idempotency conflicts are deterministic and do not mutate business state.

## Internal-helper tests

- **T044-25** — Idempotency helper functions are not treated as browser-facing business APIs.
- **T044-26** — Helper execution cannot be used to bypass command authorization or business invariants.

## Concurrency tests

- **T044-27** — Concurrent lifecycle requests serialize correctly and cannot produce an invalid final state.
- **T044-28** — Concurrent idempotent submissions produce one committed business result.
- **T044-29** — Allocation/lifecycle commands preserve existing quantity invariants under concurrent execution.

## Completion evidence

Record the schema registry, migration references, representative catalog signatures, and reproducible positive/negative/idempotency test results against the T044 completion commit.

T044 is a Phase 2 formalization task. Full implementation of future commands remains governed by Phase 3 and later milestone tasks.
