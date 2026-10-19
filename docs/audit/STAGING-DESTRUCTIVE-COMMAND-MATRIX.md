# Staging Workflow — Destructive Commands, Fallbacks, and Secret Exposure Matrix

**Audit task:** AUD-P1-003  
**Reviewed branch:** `main` at `3a8e88d6d2e3b06a6a09cf911143bba29357da83`  
**Workflows:** controlled reset, migration-history repair, staging deploy  
**Mode:** Read-only source review. No workflow or database was executed.

## Executive summary

The three manually dispatched staging workflows all declare GitHub environment `staging` and use the staging project ID `mijbpvgxrxjaalimyqgm` in their database URL construction. That static YAML evidence does not verify actual environment reviewer settings or who may dispatch workflows.

The review identified these operationally important paths:
1. The reset workflow has a remote destructive `supabase --yes db reset` command. The pre-reset backup upload can be disabled by an input.
2. The repair workflow changes remote migration-history bookkeeping using `supabase migration repair --status reverted` and `--status applied`.
3. The staging deployment workflow runs a real `supabase db push`, executes a staging UAT fixture against the remote database, and then deploys the staging Worker.
4. The staging deployment workflow checks out `${{ github.ref_name }}`, unlike the reset and repair workflows which check out `main`. If a non-main branch can be selected for dispatch, code from that branch reaches steps that receive staging secrets. The actual dispatch authorization and environment protection settings remain unverified.

## Command-by-command matrix

| Workflow / step | Command or behavior | Target / effect | Classification |
|---|---|---|---|
| Reset — local chain validation | `supabase db start`; `supabase db reset --no-seed` | Ephemeral local Supabase on the runner | Destructive to the ephemeral local DB only; not a remote target in this step |
| Reset — snapshot | `supabase migration list --db-url`; `supabase db dump --data-only` | Staging DB read; writes dump under `/tmp` | Remote read, local sensitive data artifact |
| Reset — backup upload | `actions/upload-artifact@v4` when `create_backup=true` | Stores staging data dump as one-day artifact | Data disclosure/access-control consideration; backup is optional |
| Reset — remote reset | `supabase --yes db reset --db-url "$DB_URL" --no-seed` | Configured staging DB; reconstructs schema from migrations and destroys existing data | **Destructive remote operation** |
| Reset — post-reset checks | `supabase migration list`; `supabase db push --dry-run`; `supabase db diff`; `psql` function query | Staging DB reads / dry run | Intended read-only verification |
| Repair — schema precheck | `supabase migration list`; `psql` extension query; `supabase db diff` | Staging DB reads | Intended read-only verification |
| Repair — remove obsolete history | `supabase migration repair --status reverted $OBSOLETE` | Remote migration metadata | **Remote bookkeeping mutation** |
| Repair — mark local migrations applied | `supabase migration repair --status applied $PENDING` | Remote migration metadata | **Remote bookkeeping mutation; does not run migration SQL** |
| Repair — final check | `supabase migration list`; `supabase db push --dry-run`; extension query; schema diff | Staging DB reads / dry run | Intended read-only verification |
| Deploy — quality gate | `npm run lint`; `npm run typecheck`; `npm test` | Runner only | Local CI checks |
| Deploy — apply migrations | `supabase db push --db-url ...` (no `--dry-run`) | Staging DB | **Remote schema/data change via migration chain** |
| Deploy — load UAT fixture | `psql ... -f fixtures/staging/P15-T230-UAT-FIXTURE.sql` | Staging DB | **Remote data mutation**; fixture transaction/cleanup semantics need separate source review |
| Deploy — verify fixture | `psql` count queries | Staging DB reads | Intended read-only verification |
| Deploy — build | `npm run build` | Runner only | Local build |
| Deploy — deploy Worker | `npx wrangler deploy --env staging --var ...` | Cloudflare staging Worker | **Deployment / external state change** |

## Target and fallback behavior

### Controlled reset workflow

- Target project ID and pooler host are hardcoded to the staging project/host.
- The connection user is checked against `postgres.$SUPABASE_PROJECT_ID`, and project ID is compared with the same hardcoded staging literal.
- The `confirmation` input must exactly equal `RESET STAGING`.
- The backup step is conditional on `inputs.create_backup`; dispatch can set it false, so the workflow can proceed without uploading the pre-reset dump.
- The remote reset step uses `--yes`, so there is no interactive confirmation after the workflow input guard.
- If schema verification fails after reset, the workflow exits with failure; no automatic restore step is present.

### Migration-history repair workflow

- The project ID and pooler hostname are hardcoded to staging.
- The verifier accepts only the known public-schema representation difference and the repository-equivalent `match_import_customers` function contract.
- If no remote-only migration IDs are found, the `reverted` repair command is skipped. If no local-only migration IDs are found, the `applied` repair command is skipped.
- If final verification fails, the job fails; no automatic rollback of migration-history bookkeeping is present.
- The repair commands alter migration metadata only; they do not execute the migrations being marked applied.

### Staging deployment workflow

- The workflow checks out `${{ github.ref_name }}` rather than fixed `main`. It explicitly verifies staging-related environment values in `wrangler.jsonc`, but those checks are not a full provenance check for every script or dependency that executes with secrets.
- It validates staging project ID and Supabase URL constants, and rejects the production Worker name in the staging section.
- It runs a real staging `supabase db push`, loads the P15-T230 fixture, builds, and deploys the staging Worker.
- No automatic rollback is defined for a failed migration, fixture, or deployment step in this workflow file.
- The fixture's precise data writes, transaction boundaries, idempotence, and cleanup are not established by this workflow alone and need review of `fixtures/staging/P15-T230-UAT-FIXTURE.sql`.

## Secret exposure paths and trust boundaries

| Concern | Evidence | Current assessment |
|---|---|---|
| Pull-request secret exposure | These three workflow files declare `workflow_dispatch`, not `pull_request` or `pull_request_target`. | No direct PR trigger in these files. This alone does not rule out other caller paths or repository-wide risks. |
| Non-main code in staging deploy | Deploy workflow checks out `${{ github.ref_name }}`; secret-bearing steps occur after checkout and run project code/CLI commands. | Potential code-provenance risk if users can dispatch a non-main branch. Actual permissions/settings unverified. |
| Staging DB password | Referenced as `secrets.STAGING_SUPABASE_DB_PASSWORD` in reset, repair, and deploy workflows. | Secret name is confirmed; existence, value validity, and environment scoping not verified. |
| Cloudflare token | Referenced as `secrets.CLOUDFLARE_API_TOKEN` in deploy workflow. | Name is confirmed; value validity and environment scoping not verified. |
| Supabase publishable key | Referenced as `secrets.STAGING_SUPABASE_PUBLISHABLE_KEY` in deploy workflow. | Name is confirmed; publishable keys are client-facing credentials, not equivalent to a service-role secret. |
| Environment protection | All three jobs declare `environment: staging`. | Reviewer requirements, allowed branches/tags, and deployment protection rules cannot be inferred from YAML alone. |
| External actions | References use tags such as `actions/checkout@v4`, `supabase/setup-cli@v1`, and `actions/upload-artifact@v4`. | Mutable-tag supply-chain concern; full SHA pinning is a separate audit item. |

## Approval and execution boundary

This report is analysis only. It does not authorize running any workflow. In particular:
- Do not run the reset workflow as part of this audit.
- Do not run migration repair against a connected database.
- Do not run the staging deployment workflow as a way to test this review.
- Any future guard proposal or dummy-input harness must be kept separate from live workflow execution; changes to workflows require explicit approval.
- Production database/schema/data and production deployment remain out of scope.

## Next

AUD-P1-004 is to design fail-closed staging-target guards, production host/project rejection, typed confirmation, and a protected-environment gate as a written proposal and dummy-input matrix only. Workflow edits remain unapproved and must not be applied.
