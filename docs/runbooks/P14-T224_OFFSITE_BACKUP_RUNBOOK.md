# P14-T224 — Off-site Backup Runbook

## Purpose

Define a controlled procedure for moving verified production recovery artifacts to an independent, secure storage location.

This milestone documents the off-site backup control. It does **not** claim that a production backup has already been copied, that a particular storage provider is configured, or that a restore has been successfully performed.

## Recovery-source model

The project uses multiple recovery sources with different purposes:

1. **Version-controlled migrations** — authoritative source for schema evolution.
2. **Supabase-managed backups** — platform recovery baseline when the selected production plan provides them.
3. **Logical PostgreSQL exports** — portable application-data recovery artifact documented by P14-T223.
4. **Independent off-site copy** — protects the logical export against loss or unavailability of the primary storage/control plane.

An off-site copy must not be treated as a substitute for tested restoration.

## Preconditions

Before transferring an export:

- Verify the artifact came from the production environment.
- Confirm the export timestamp, application commit SHA and migration state.
- Confirm the artifact passed the P14-T223 structural/integrity checks.
- Confirm the SHA-256 checksum is recorded before transfer.
- Use an approved storage location controlled independently of the production database.
- Use encryption at rest and encrypted transport.
- Restrict access to authorized recovery operators.
- Do not place production data, credentials or storage keys in GitHub.

## Transfer procedure

1. Select the verified logical-export artifact.
2. Create or select the approved encrypted off-site storage location.
3. Transfer the artifact using the storage provider's authenticated secure transport.
4. Record the destination object/path identifier without recording secrets.
5. Verify the transferred object's byte size.
6. Recalculate or provider-verify the SHA-256 checksum where supported.
7. Confirm the checksum matches the source artifact.
8. Record the completion timestamp in UTC and the evidence reference.

If checksum verification fails, treat the off-site copy as invalid and repeat the transfer rather than accepting a mismatched artifact.

## Minimum backup record

For each off-site copy record:

- environment: production
- project/reference identifier
- source export filename
- source export timestamp UTC
- application commit SHA
- migration state/reference
- artifact size in bytes
- source SHA-256
- destination storage location/object identifier
- destination checksum or integrity verification result
- encryption classification
- access-control reference
- retention/expiry date
- transfer timestamp UTC
- operator/evidence reference

## Retention

Retention must be defined before production recovery artifacts are stored. The retention policy must identify:

- minimum number or age of retained recovery points;
- expiry/deletion authority;
- legal or business retention overrides, if applicable;
- how expired copies are securely deleted;
- how deletion evidence is recorded.

Do not silently delete the only known recovery copy.

## Security controls

- Never store database credentials beside the backup artifact.
- Never expose production backup objects publicly.
- Prefer separate credentials/roles for backup writing and restoration where the storage platform supports them.
- Enable versioning or immutable/object-lock controls where they are approved and supported by the chosen storage platform.
- Keep encryption keys under an access-control boundary separate from ordinary application users where practical.
- Log access and administrative changes where the storage platform supports audit logging.

## Verification boundary

A successful upload and matching checksum demonstrate artifact transfer integrity. They do **not** demonstrate that the database can be restored.

Restore testing is a separate milestone and must use a non-production target unless an explicitly approved production recovery event requires otherwise.

## Failure handling

If the transfer fails, the destination object is incomplete, or checksum verification fails:

1. Mark the copy invalid.
2. Do not use it as a recovery source.
3. Preserve the source artifact while investigating.
4. Retry through the approved transfer mechanism.
5. Record the failure and final verified result.

If no verified off-site copy exists, record the recovery gap rather than claiming backup coverage.

## Production boundary

This runbook is intentionally provider-neutral. No storage account, bucket, credential, key, or production data is embedded in the repository. Actual configuration and transfer require an authorized control-plane operator.
