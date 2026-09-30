# P15-T242 — Backup / Restore Acceptance Evidence Framework

## Purpose

Provide a repository-controlled validation framework for P15-T242 without claiming that a backup or restore has occurred.

This framework separates four controls:

1. **Export evidence** — an actual logical PostgreSQL export exists.
2. **Integrity evidence** — the export has a recorded size and SHA-256 checksum and is readable by PostgreSQL tooling.
3. **Restore evidence** — the verified export has been restored to an isolated non-production PostgreSQL target.
4. **Recovery validation** — the restored target passes structural, constraint, representative-data, access-boundary, and application read-only checks.

A repository migration, runbook, or successful SQL validation does **not** substitute for the actual export or restore evidence.

## Required evidence record

| Field | Required |
|---|---|
| Drill ID | Yes |
| Source environment/project | Yes |
| Export artifact identifier | Yes |
| Export timestamp UTC | Yes |
| Application commit SHA | Yes |
| Migration state/reference | Yes |
| Dump format | Yes |
| Dump size in bytes | Yes |
| SHA-256 | Yes |
| PostgreSQL archive inspection result | Yes |
| Restore target identifier | Yes |
| Restore target PostgreSQL version | Yes |
| Production isolation confirmed | Yes |
| Restore start/end UTC | Yes |
| Restore exit status | Yes |
| Structural validation result | Yes |
| PK/unique/FK validation result | Yes |
| Index validation result | Yes |
| Representative row-count result | Yes |
| Application read-only checks | Yes |
| RPO measurement | Yes |
| RTO measurement | Yes |
| Operator/evidence reference | Yes |

## Acceptance gates

### Gate A — Export

PASS only when the actual export artifact is available, non-empty, and its exact byte size and SHA-256 are recorded.

### Gate B — Archive integrity

PASS only when PostgreSQL tooling can inspect the custom-format archive without error. Archive inspection is necessary but does not prove a successful restore.

### Gate C — Isolated restore

PASS only when the archive is restored to a non-production target with no application production endpoint or production write path attached.

### Gate D — Database validation

PASS only when the restored target contains the required application tables and passes structural/constraint/index checks and representative row-count validation.

### Gate E — Application validation

PASS only when the restored target supports read-only checks for critical Orders, reporting, authentication/profile, and reconciliation paths.

### Gate F — Recovery measurements

RPO and RTO must be calculated from actual recorded timestamps. Documented targets must not be presented as measured results.

## Explicit non-claims

The following do not constitute P15-T242 completion:

- the existence of the P14-T223/P14-T224/P14-T225 runbooks;
- a successful migration replay;
- a healthy Supabase project;
- a schema-only test;
- a checksum without a restore;
- a readable dump without a restore;
- a restore without post-restore validation;
- a documented RPO/RTO target without measured timestamps.

## Security boundary

Production database dumps contain business data and must not be committed to GitHub. Store the artifact only through the approved encrypted/off-site recovery storage mechanism. Commit only metadata/evidence that does not expose credentials or production data.

## Current status

P15-T242 remains **IN PROGRESS** until Gates A–F have real runtime evidence. This repository framework is validation infrastructure, not the missing backup artifact or restore result.
