# P14-T226 — Recovery Drill Evidence Contract

## Purpose

Define the evidence required to record an actual non-production recovery drill. This document complements the P14-T225 restore-testing procedure and does not claim that a recovery drill has been executed.

## Execution gate

A drill may be recorded as **PASS** only when all applicable evidence fields below are populated and independently verifiable. Missing recovery artifacts, target access, credentials, or validation evidence means the drill remains **NOT EXECUTED** or **INCOMPLETE**.

## Required evidence record

| Field | Requirement |
|---|---|
| Drill ID | Unique identifier |
| Source artifact ID | Exact logical-export artifact reference |
| Source SHA-256 | Exact recorded checksum |
| Export timestamp UTC | Recovery-point timestamp |
| Application commit SHA | Commit associated with the recovery source |
| Migration/reference state | Recorded and explainable |
| Target environment | Isolated non-production target identifier |
| Target PostgreSQL version | Recorded and compatible |
| Target safety verification | Evidence target is not production |
| Archive inspection | `pg_restore --list` or equivalent result |
| Restore start/end UTC | Actual timestamps |
| Restore exit status | Actual command result |
| Structural validation | Schemas, tables, functions/views where applicable |
| Constraint validation | PK/unique/FK checks |
| Index validation | Expected indexes verified |
| Representative counts | Compared with source/export evidence |
| Application read-only checks | Representative operational/reporting queries |
| RPO measurement | Calculated only from actual timestamps |
| RTO measurement | Calculated only from actual restore/validation timestamps |
| Failure details | Required when any check fails |
| Operator | Person executing the drill |
| Approval reference | Required according to recovery procedure |

## PASS criteria

A drill can be marked PASS only if:

1. The source checksum matches.
2. The archive is readable and enumerable.
3. The target is confirmed non-production and isolated.
4. Restore completes successfully.
5. Structural, constraint, and index validation passes.
6. Representative data validation is consistent with the available source evidence.
7. Read-only application checks pass where applicable.
8. RPO/RTO measurements are supported by the recorded timestamps.
9. No production endpoint was used.
10. The evidence record is complete and reviewable.

## Non-execution rule

The existence of this contract, P14-T225, a backup runbook, or a recovery artifact does **not** constitute a successful restore. A successful drill requires execution evidence from an isolated non-production target.

## Failure handling

If any gate fails, record the drill as **FAILED** or **INCOMPLETE**, preserve the source artifact, record the failure class and exit status, and do not modify production as part of the drill.
