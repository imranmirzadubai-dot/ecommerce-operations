# P14-T225 — Restore Testing Runbook

## Purpose

Define a controlled, non-production restoration test for a verified PostgreSQL logical export. The objective is to demonstrate that a recovery artifact can be restored and structurally validated without modifying production.

This milestone documents the test procedure. It does **not** claim that a production database has been restored, that a production backup exists, or that a successful restore has already been executed.

## Recovery source

Use a logical export that has completed the P14-T223 integrity and structural checks and, where applicable, the P14-T224 off-site transfer integrity checks.

The recovery artifact must have a recorded:

- source environment and project reference;
- export timestamp UTC;
- application commit SHA;
- migration state/reference;
- SHA-256 checksum;
- artifact size;
- storage/object reference.

## Safety boundary

- Restore only to an isolated non-production PostgreSQL target.
- Never point restore commands at the production database.
- Use dedicated recovery credentials with the minimum required privileges.
- Do not expose credentials, connection strings, backup contents, or secrets in GitHub.
- Do not run destructive cleanup commands against production.

## Preconditions

1. Confirm the target is non-production.
2. Confirm the source artifact checksum before restore.
3. Confirm the export is from the intended production project/environment.
4. Confirm the target PostgreSQL major version is compatible with the export.
5. Confirm sufficient target storage.
6. Confirm the migration/reference metadata associated with the export is recorded.

If any precondition fails, stop and record the recovery gap.

## Restore procedure

1. Provision or select an isolated disposable PostgreSQL target.
2. Verify the target identity and connection endpoint.
3. Verify the source artifact SHA-256 checksum.
4. Inspect the archive with `pg_restore --list` before applying it.
5. Create the target database using the approved recovery credentials.
6. Restore using `pg_restore` with the approved options for the artifact format.
7. Capture command output and exit status as recovery evidence without storing secrets.
8. Re-run structural inspection with `pg_restore --list` or equivalent database catalog checks.
9. Run schema/table/function/index checks appropriate to the exported application state.
10. Compare key object counts and constraints with the export manifest or source evidence where available.
11. Record restore duration, target version, artifact checksum, and validation result.
12. Destroy or securely reset the disposable target according to the approved retention policy.

## Validation gates

A restore test is successful only when all applicable checks pass:

- artifact checksum matches the recorded source checksum;
- archive can be enumerated;
- restore exits successfully;
- expected schemas exist;
- expected tables exist;
- expected functions/views exist where included in the export;
- expected primary/unique/foreign-key constraints exist;
- expected indexes exist;
- representative row counts are consistent with the export evidence;
- application migration/reference state is recorded and explainable;
- no production endpoint was used as the restore target.

A successful command alone is insufficient evidence.

## Application-level verification

After database-level validation, run safe read-only application checks against the isolated target where the environment supports them. Validate representative reporting and operational queries without sending production traffic.

Do not treat a successful schema restore as proof that the entire application is recoverable until application-level checks also pass.

## Failure handling

If restore fails or validation is incomplete:

1. Mark the recovery point as unverified for restore purposes.
2. Preserve the original artifact.
3. Capture the failure class and command exit status.
4. Do not alter production to compensate for a failed test.
5. Investigate version, extension, permission, ownership, encoding, or artifact issues as applicable.
6. Repeat only after the failure cause and target safety have been reviewed.

## Evidence record

Record:

- test identifier;
- source artifact identifier and SHA-256;
- source export timestamp;
- application commit SHA;
- migration/reference state;
- target environment identifier;
- PostgreSQL version;
- restore command class (without secrets);
- restore start/end UTC;
- restore duration;
- validation checks and results;
- representative object/row counts;
- failure details, if any;
- operator and approval reference.

## RPO/RTO measurement

The test may measure:

- **RPO:** timestamp of the latest recoverable export relative to the incident/data-loss point;
- **RTO:** elapsed time from recovery initiation to a validated usable non-production database.

Do not publish an RPO/RTO target as achieved until an actual test has produced evidence supporting it.

## Production recovery boundary

This runbook does not authorize production restoration. A real production recovery requires an incident/recovery decision, an approved recovery source, verified credentials, a controlled execution window, and post-restore validation.
