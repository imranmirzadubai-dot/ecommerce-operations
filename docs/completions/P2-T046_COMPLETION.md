# P2-T046 Completion Record

## Task

**P2-T046 — Formalize historical import identity rules**

## Status

**COMPLETE — architecture contract formalized.**

## Completion date

2026-09-12

## Branch

`feature/t046-import-identity-rules`

## Evidence commit

`07ef280cf91dc8ad554242436255fc1b191351d5`

## Task Completion Reference

`ECO-TCR-P2-T046-20260912-07ef280c`

## Deliverables

- `docs/architecture/IMPORT_IDENTITY_RULES.md`
- `docs/test-plans/T046_IMPORT_IDENTITY_TEST_PLAN.md`
- this completion record

## Formalized contract

T046 establishes distinct identity layers for:

1. immutable internal import-batch UUID;
2. preserved source-system record identity when supplied;
3. immutable physical source-row identity within a batch;
4. authoritative internal domain identity after mapping.

It also establishes rules for raw versus normalized source evidence, duplicate/conflict classification, re-import and replay handling, source-content fingerprinting as a future implementation requirement, protection of internal sequence identifiers, explicit source-to-domain mapping lineage, Admin-only authorization, append-oriented historical evidence, and auditable rollback.

## Current-schema boundary

The current foundation schema already provides batch UUID identity, row UUID identity, the `batch_id` relationship, positive `source_row_number`, unique `(batch_id, source_row_number)`, optional `source_record_id`, `raw_data`, and `normalized_data`.

The current schema does not yet enforce source-content fingerprints, source-system-specific `source_record_id` uniqueness, or a persisted source-to-domain mapping model. These are explicitly recorded as Phase 3 implementation requirements rather than silently implemented during T046.

## Verification

Repository review confirmed the import staging model and its relationship to the existing identifier, authorization, RLS, command, and audit contracts. No production or staging business data was modified by T046.

## Acceptance decision

**FORMALIZED — T046 complete.**

Phase 3 import schema, commands, reconciliation, security hardening, and executable tests must implement the contract defined by this task.
