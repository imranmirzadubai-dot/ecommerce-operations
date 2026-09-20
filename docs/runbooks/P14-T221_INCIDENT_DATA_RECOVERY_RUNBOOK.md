# P14-T221 — Incident / Data Recovery Runbook

## Purpose

Provide a controlled procedure for incidents affecting application availability, authentication, operational data integrity, or database availability, with explicit separation between containment, application recovery, database recovery, and verified restoration.

## 1. Incident declaration

Declare an incident when there is a material availability, authentication, security, data-integrity, or critical operational/reporting failure.

Record:
- incident/reference ID
- affected environment
- first observed time and detection source
- affected application paths/data domains
- current deployed commit
- relevant migration status
- operator and escalation owner

## 2. Immediate containment

1. Stop further deployments and migrations.
2. Preserve relevant structured logs, correlation IDs, timestamps and error details.
3. Identify whether the problem is application, database, authentication, deployment, or external dependency related.
4. Avoid destructive corrective actions until the affected state and evidence are recorded.
5. If credentials or secrets may be exposed, follow the applicable credential-rotation procedure and invalidate affected access where supported.

## 3. Application recovery

If application code is the cause:
1. Identify the last known-good reviewed deployment.
2. Follow P14-T220 application rollback procedure.
3. Verify availability, authentication and critical Orders/reporting paths.
4. Record failed and recovered commit/deployment identifiers.

## 4. Database/data-integrity recovery

First determine whether data is:
- available and correct;
- available but inconsistent;
- unavailable;
- suspected to be corrupted or unintentionally modified.

For schema defects, prefer a reviewed forward corrective migration when safe. Do not execute an unreviewed destructive rollback of an applied production migration.

For suspected data corruption or unintended mutation:
1. Stop further writes where operationally safe.
2. Preserve evidence and identify the affected records/time range.
3. Determine the authoritative recovery source available for the environment.
4. Establish a recovery plan and approval before restoration or data repair.
5. Perform restoration/repair using the verified platform procedure.
6. Reconcile restored data against authoritative invariants, audit/event history and expected counts.
7. Record exactly what was restored, repaired, excluded or recreated.

## 5. Recovery verification

Before declaring recovery complete:
- application is reachable;
- authentication/session behavior is functional;
- core Orders/reporting reads work;
- database connectivity is healthy;
- expected RLS/access boundaries remain intact;
- no unexpected new mutations are observed;
- logs contain timestamps, severity/context and correlation IDs;
- recovered commit/database state is recorded;
- incident owner confirms the evidence package is complete.

## 6. RPO/RTO recording

Record:
- incident start/detection time;
- recovery start time;
- service restoration time;
- data restoration point/time where applicable;
- observed data-loss window, if any;
- actual recovery duration;
- dependencies that prevented earlier recovery.

Do not substitute documented targets for measured recovery results.

## 7. Closure

Close only after:
1. technical recovery is verified;
2. affected business flows are checked;
3. data reconciliation is completed where applicable;
4. incident evidence is retained;
5. unresolved follow-up actions are assigned;
6. actual impact and recovery measurements are recorded.

## Recovery-source boundary

This runbook does not assert that production backups, logical exports, off-site copies, restore credentials, point-in-time recovery, or a tested production restore are currently available. Those controls require separate verification in P14-T222 through P14-T225.

## Scope boundary

This is an operational procedure, not a claim of completed disaster-recovery testing. No production data is changed by documenting this runbook.
