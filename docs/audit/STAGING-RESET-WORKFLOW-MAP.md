# Staging Reset Workflow — Trigger and Target Map

**Audit task:** AUD-P1-001  
**Reviewed file:** `.github/workflows/controlled-staging-database-reset.yml` on `main`  
**Workflow blob SHA:** `5eb238271b971df108a218fcfc9fd64e8a1f48cf`  
**Review mode:** Read-only. The workflow was not executed.

## Trigger and actor path

1. The only declared trigger is `workflow_dispatch`; no push, pull-request, schedule, or `workflow_call` trigger is declared in this file.
2. Manual dispatch requires a string input named `confirmation`; the workflow fails unless it exactly equals `RESET STAGING`.
3. `create_backup` is a required boolean input with default `true`. A dispatcher can set it to `false`, which skips the backup-artifact upload step.
4. The reset job targets GitHub Actions environment `staging`.
5. The workflow checks out `main` at dispatch time (shallow, depth 1), not the triggering branch's code.
6. A concurrency group serializes runs of this workflow and does not cancel an in-progress run.

**Important distinction:** the typed confirmation is an input guard, not proof of who is authorized to run the workflow. The GitHub environment's configured required reviewers, deployment branch rules, and actual dispatch permissions were not accessible through the read-only repository-file inspection. Treat these as **unverified**, not as enabled or absent.

## Permissions and secrets

Job-level permissions are:
- `contents: read`
- `actions: write`

The workflow reads `secrets.STAGING_SUPABASE_DB_PASSWORD` in steps that construct or use the database URL. It does not print the password; the URL is written to `/tmp/staging-db-url` with mode 600. The workflow prints the fixed project ID, pooler host, and database username. No secret values were accessed or copied into this report.

The database password secret's existence and validity are not verified here. The workflow depends on the `staging` environment binding, but environment reviewer configuration is unknown.

## Target construction and guards

The target values are hardcoded in the workflow job:
- Project ID: `mijbpvgxrxjaalimyqgm`
- Pooler host: `aws-0-ap-south-1.pooler.supabase.com`
- Expected database user: `postgres.mijbpvgxrxjaalimyqgm`

The connection URL is built from those constants plus the encoded `STAGING_SUPABASE_DB_PASSWORD`. Shell checks require a non-empty password, verify the parsed username, and compare the project ID to the same expected literal. These guards make the current static target explicit, but the project-ID check is not an independent comparison against a protected environment variable or a separate trusted source. The URL/host are not user inputs in this workflow.

## Destructive and data-handling path

1. Start an ephemeral local Supabase database.
2. Run `supabase db reset --no-seed` against that local environment to validate the repository migration chain.
3. Read the current staging migration history.
4. Dump staging data to `/tmp/staging-data.sql`, print its SHA-256 and line count.
5. If `create_backup=true`, upload that dump as an artifact with a one-day retention period.
6. Run `supabase --yes db reset --db-url "$DB_URL" --no-seed` against the configured staging target. This is the destructive remote operation.
7. Verify migration history, dry-run pending migrations, compare the public schema, and query for three expected runtime functions.

The artifact is a short-lived data backup, but it is not a demonstrated restore procedure. Because the input allows the backup step to be disabled, a successful run does not necessarily mean a pre-reset data artifact exists. No restore/rollback step is present in this workflow file.

## Actor / trigger matrix

| Entry point | Declared here? | Effect |
|---|---|---|
| Manual `workflow_dispatch` | Yes | Starts reset job after exact typed confirmation and normal GitHub/environment gates. |
| Push / pull request / schedule | No | No automatic trigger declared in this file. |
| Reusable `workflow_call` | No | No reusable-workflow entry point declared in this file. |
| GitHub environment reviewer gate | Referenced as `staging`, settings unknown | Actual approval gate cannot be confirmed from repository YAML alone. |

## Findings and limits

- **Verified from YAML:** the remote reset command is destructive; the target project ID and host are hardcoded to the staging values listed above; the password comes from the staging-named secret; the backup upload is optional; the workflow requires a literal confirmation string.
- **Not verified:** required environment reviewers, deployment branch restrictions, who can dispatch, secret existence/validity, artifact access restrictions, and whether repository/environment settings provide additional controls.
- **Not done:** workflow execution, remote DB connection, migration/reset/repair, or any database mutation.

## Next audit step

AUD-P1-002 should trace `repair-staging-migration-history.yml`, its script dependencies, secrets/variables, and all reusable workflow/script call paths. AUD-P1-003 should enumerate destructive commands and fallback behavior across both workflows. No workflow changes are proposed or applied in this task.
