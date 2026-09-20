# P14-T223 — Logical Export Runbook

## Purpose

Define a repeatable, evidence-producing procedure for creating a logical PostgreSQL export of the production system without committing credentials, connection strings, or production data to the repository.

This milestone documents and standardizes the export procedure. It does **not** claim that a production export has already been executed, stored off-site, or successfully restored.

## Scope

The export is a PostgreSQL logical dump of the application database. The repository remains the source of truth for schema migrations; the logical dump is a recovery/data-portability artifact, not a replacement for version-controlled migrations.

## Preconditions

Before an export:

1. Confirm the target environment is production and record the project/reference identifier.
2. Confirm the operator is authorized to access the production database.
3. Use a secret-managed connection string or approved Supabase database access method. Never place credentials in shell history, source files, commits, tickets, or logs.
4. Confirm sufficient local encrypted storage for the expected dump and checksum.
5. Record the current application commit and applicable migration state.
6. Do not run an export from an unverified environment.

## Export procedure

Use the approved production database connection string supplied through the secret-management/control-plane mechanism. Run `pg_dump` with a custom-format output so the artifact can be inspected and restored selectively with `pg_restore`.

Example command shape (replace placeholders locally; do not commit the real value):

```text
pg_dump --dbname="$PRODUCTION_DATABASE_URL" --format=custom --file="ecommerce-operations-production-YYYYMMDD-HHMMSS.dump"
```

For a schema/data export suitable for recovery, include the application's required schemas and exclude platform-managed objects unless the approved recovery procedure specifically requires them. If the Supabase-supported export method differs for the active platform configuration, use that documented method instead of forcing a raw connection approach.

## Artifact handling

For every completed export, create a companion record containing:

- environment: production
- project/reference identifier
- export timestamp in UTC
- source database/server identity where available
- application commit SHA
- migration state/reference
- dump filename
- dump format
- dump size in bytes
- SHA-256 checksum
- operator/evidence reference
- storage location/classification
- retention/expiry date

The dump itself must be encrypted at rest and transferred only through an approved secure storage channel. Do not upload production data to GitHub or store it in this repository.

## Integrity verification

Immediately after export:

1. Confirm the file exists and is non-empty.
2. Record its exact byte size.
3. Calculate and record SHA-256.
4. Verify the dump can be read by the PostgreSQL tooling without error.
5. Record the command/tool version used for the verification.

Example inspection command shape:

```text
pg_restore --list "ecommerce-operations-production-YYYYMMDD-HHMMSS.dump"
```

A readable table-of-contents listing is evidence that the custom-format artifact is structurally readable; it is **not** evidence of a successful restore.

## Recovery relationship

Use the latest verified logical export only as one recovery source. For a database incident, first establish the recovery point and impact using P14-T221, then select the appropriate recovery source and obtain required approval before restoration.

Database schema recovery should follow the repository migration chain where appropriate. Do not infer that restoring an old logical dump also restores the correct application version or migration state.

## Retention and rotation

Retention must be defined by the production recovery policy and storage provider. When an export expires, remove it through the approved secure-storage process and retain the evidence record required by policy. Never delete the only known recovery artifact without confirming another verified recovery source exists.

## Evidence gate

A logical-export milestone is operationally evidenced only when an actual export has been executed and the following are recorded:

- export artifact identifier
- timestamp
- size
- SHA-256
- structural verification result
- secure storage location
- retention date
- operator/evidence reference

This repository milestone establishes the procedure and evidence contract. It does not manufacture those runtime values.

## Failure handling

If export or verification fails:

1. Preserve the error and correlation/evidence details without exposing credentials.
2. Do not mark the export as verified.
3. Determine whether the failure is authentication, connectivity, capacity, permissions, tooling, or database related.
4. Retry only after the cause is understood and the target environment is re-verified.
5. Escalate persistent production failures through the incident/recovery procedure.

## Security boundaries

- Never commit `PRODUCTION_DATABASE_URL` or any credential.
- Never commit `.dump`, `.sql`, or other production-data artifacts.
- Never place passwords in command examples, documentation, CI variables, or issue comments.
- Treat exported customer/order/financial data as production business data with restricted access.
- A successful export does not prove off-site durability or restore capability; those are separate controls covered by subsequent recovery milestones.
