# P14-T220 — Deployment / Rollback Runbook

## Purpose

Provide a controlled operational procedure for deploying the single React + TypeScript + Vite application to its environment and recovering from an unsuccessful deployment.

## Locked Architecture

- One application deployment per environment using Cloudflare Workers.
- Supabase PostgreSQL and Supabase Auth are separate environment dependencies.
- GitHub `main` is the production source-of-truth branch.
- Feature branches and previews must not use production business data.

## Pre-deployment gate

1. Confirm the target environment and branch/ref.
2. Confirm the intended commit is the reviewed/approved commit.
3. Confirm GitHub CI is green: lint, TypeScript typecheck, unit tests, build, and isolated Supabase database tests.
4. Confirm required database migrations are present in version control and have passed the applicable database checks.
5. Confirm no production secrets are present in source control or browser code.
6. Confirm a rollback target is known: the last verified production commit/deployment.
7. For database changes, determine whether the migration is backward-compatible before application deployment.

## Deployment sequence

1. Merge only the reviewed PR after required approval and CI gates.
2. Record the merge commit SHA.
3. Deploy the exact reviewed/merged commit to the target Cloudflare Worker environment through the repository's approved deployment mechanism.
4. Record the deployment identifier, timestamp and commit SHA.
5. Run smoke checks for application availability, authentication and critical read-only/reporting paths.
6. If database migrations are part of the release, verify migration completion before declaring the release operational.

## Rollback decision

Initiate rollback when a release causes a material availability, authentication, data-integrity, security or critical-function regression that cannot be safely mitigated in place.

## Application rollback

1. Stop further promotion.
2. Identify the last known-good application commit/deployment.
3. Redeploy that exact known-good application version.
4. Verify the Worker serves the expected version and smoke checks pass.
5. Record the incident, failed release SHA, rollback SHA, timestamps and observed impact.

## Database rollback boundary

Do **not** automatically reverse an applied production database migration unless the migration has an explicitly reviewed, safe rollback procedure. Prefer forward-compatible corrective migrations when data or schema state has already changed.

For destructive or irreversible changes, treat rollback as an application/data-recovery procedure rather than assuming `down` migration semantics.

## Post-rollback verification

- Application availability
- Authentication/session behavior
- Critical Orders/reporting read paths
- Database connectivity
- No unexpected data mutation
- Logs contain sufficient timestamp/context information for investigation
- Capture final deployed commit and evidence

## Recovery and evidence

Every deployment/rollback record should contain target environment, source/merge commit, deployment identifier, operator, timestamps, outcome, smoke-test result, migration status and any incident/reference ID.

## Scope boundary

This runbook documents the controlled procedure and decision boundary. It does not claim that production deployment credentials, Cloudflare production configuration, automated rollback, database backups, restore capability, or a tested production disaster-recovery process have been independently verified. Those are separate controls and milestones.
