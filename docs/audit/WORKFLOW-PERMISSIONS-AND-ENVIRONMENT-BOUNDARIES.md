# AUD-P1-006 — Workflow Permissions and Environment-Boundary Review

**Status:** Read-only review; recommendations only.
**Scope:** Staging reset, staging migration repair, staging deploy, production deploy, and Wrangler environment configuration on main.
**Safety:** No workflow was dispatched. No credentials were read. No database, schema, data, or deployment was accessed or changed.

## Summary

The reviewed workflows use the GitHub `workflow_dispatch` trigger. The staging and production deploy jobs use separate project URLs and environment names, but GitHub-side protection settings were not verified. Staging deploy checks out the dispatch-selected ref while receiving staging credentials and performing migrations, fixture loading, and Worker deployment. Production deploy has authority to write a production Worker secret and deploy the production Worker. These are control points requiring review; they do not prove unauthorized access is possible.

## Evidence

### Staging reset — `.github/workflows/controlled-staging-database-reset.yml`

- Uses the `staging` environment, checks out `main`, and declares `contents: read` plus `actions: write` permissions.
- Requires the typed phrase `RESET STAGING` and checks a hard-coded staging project ID and pooler host.
- Backup upload is conditional on `inputs.create_backup`; the reset can proceed when that input is false.
- The workflow includes a remote destructive reset and post-reset verification.

Recommendation: require a verified backup before reset, add a final exact-target check immediately before the reset command, and verify whether `actions: write` is necessary for the artifact upload before changing it.

### Staging migration repair — `.github/workflows/repair-staging-migration-history.yml`

- Uses the `staging` environment, checks out `main`, and declares `contents: read`.
- Uses the staging database password for schema/history checks and migration-history repair commands.
- Repair commands change remote migration-history metadata.

Recommendation: require a protected environment with reviewer approval, preserve a read-only before/after plan, and verify the target immediately before each repair command.

### Staging deploy — `.github/workflows/deploy-staging.yml`

- Uses the `staging` environment and declares `contents: read`.
- Checks out `${{ github.ref_name }}`, not a fixed reviewed ref.
- Uses staging credentials to apply migrations, load a UAT fixture, and deploy a staging Worker.
- Uses the Supabase CLI version `latest`, reducing repeatability.

Recommendation: restrict the deploy ref to a fixed reviewed ref or strict allowlist before credentials are made available. Pin the CLI version and keep final target checks immediately before each mutating step.

### Production deploy — `.github/workflows/deploy-production.yml`

- Uses the `Production` environment, checks out `main`, and declares `contents: read`.
- Receives production Supabase credentials and a Cloudflare token in the deploy step.
- Writes the production Supabase secret to the Worker and deploys the production Worker.
- Does not run database migrations in the reviewed version.

Recommendation: verify environment reviewer rules, dispatch permissions, branch restrictions, and Cloudflare token scope before any deployment. A narrow GitHub token permission does not by itself constrain external credentials.

### Wrangler configuration — `wrangler.jsonc`

- The top-level Worker is `ecommerce-operations` and top-level vars identify the production environment and production Supabase URL.
- The `staging` environment names `ecommerce-operations-staging` and uses the staging Supabase URL.
- Comments say production URL/publishable key are not committed, but top-level vars contain production values. The publishable key is not a service-role secret, but the comment and configuration conflict.

Recommendation: trace config consumers and deployment behavior, then reconcile the comment/configuration in a separately reviewed change. Do not remove or rewrite runtime values as part of this audit.

## Control matrix

| Control | Reset | Repair | Staging deploy | Production deploy |
|---|---|---|---|---|
| Protected environment and required reviewer | Required | Required | Required | Required |
| Authorized workflow dispatchers | Verify | Verify | Verify | Verify |
| Fixed reviewed ref | Already checks out main; verify workflow-source controls | Already checks out main; verify workflow-source controls | Replace selected arbitrary ref | Fixed main checkout; verify workflow-source controls |
| Least-privilege permissions | Review `actions: write` necessity | `contents: read` appears narrow | `contents: read` appears narrow | `contents: read` appears narrow |
| Exact target check immediately before mutation | Required | Before each repair command | Before migrations, fixture, deploy | Before secret write and deploy |
| Backup/recovery | Mandatory verified backup | Record before/after history | Fixture idempotency and recovery plan | Release rollback plan |
| Tool/action pinning | Full SHA and fixed CLI | Full SHA and fixed CLI | Full SHA and fixed CLI; remove `latest` | Full SHA where applicable |

## Settings that remain unverified

1. GitHub environment reviewer rules, deployment branch restrictions, and environment-scoped credential configuration.
2. Repository/organization rulesets and branch protections.
3. Who may dispatch and approve each workflow.
4. Cloudflare token scope and whether the staging token is technically unable to deploy production resources.
5. Whether the reset artifact action requires `actions: write` for this exact version.
6. Whether top-level Wrangler vars are relied on by local development or other build paths.

## Priority

1. Verify production approvals and dispatch controls.
2. Restrict staging deploy source refs.
3. Require reset backup and final target checks.
4. Verify Cloudflare token scope and GitHub token permissions.
5. Pin action refs and the staging CLI version.
6. Resolve the Wrangler comment/configuration mismatch after tracing consumers.

## Exclusions

No workflow, repository setting, or runtime configuration was changed. No credentials were read or rotated, and no workflow was dispatched, database accessed, reset performed, migration repaired, fixture loaded, deployment made, or PR merged.