# Staging Migration-History Repair — Workflow and Script Map

**Audit task:** AUD-P1-002  
**Reviewed against:** `main` at `3a8e88d6d2e3b06a6a09cf911143bba29357da83`  
**Workflow:** `.github/workflows/repair-staging-migration-history.yml`  
**Workflow blob SHA:** `56a9f9a4560a1e3dd0d324b093fe599b855df6e0`  
**Script:** `scripts/verify-staging-public-schema.py`  
**Script blob SHA:** `9f95132a34fe0254f19353c83d21f39b6f7a8c06`  
**Review mode:** Read-only; workflow not executed.

## 1. Trigger, job, and checkout

- Only `workflow_dispatch` is declared.
- A concurrency group serializes this workflow; `cancel-in-progress: false`.
- One job runs on `ubuntu-latest`, timeout 45 minutes, in GitHub environment `staging`.
- Job permissions are `contents: read`.
- It checks out `main` at dispatch time with `fetch-depth: 1`.
- Supabase CLI is installed at fixed version `2.98.2`.
- The project ID is hardcoded as `mijbpvgxrxjaalimyqgm`.

No `workflow_call`, push, pull-request, or schedule trigger is declared in this file. The GitHub environment's configured reviewers, allowed deployment branches, and dispatch access were not available from the YAML, so their presence/absence is **unverified**.

## 2. Secret and connection construction

The workflow references `secrets.STAGING_SUPABASE_DB_PASSWORD` in each database-access step. It URL-encodes that secret and constructs a PostgreSQL URL with:
- user: `postgres.mijbpvgxrxjaalimyqgm`
- host: `aws-0-ap-south-1.pooler.supabase.com`
- database: `postgres`

Unlike the reset workflow, this repair workflow does not write a persistent URL file; each step constructs the URL in its own shell. The secret is not echoed. The secret's existence and validity were not tested.

No other secret, repository variable, environment variable, reusable workflow, or external script is referenced by this workflow beyond the listed Supabase password, the fixed constants, GitHub's `github.ref_name`-independent checkout of `main`, and the local Python verifier. The Python verifier reads a migration file from the checked-out repository.

## 3. Step-by-step execution and mutation map

| Step | Action | Read-only or mutation | Risk / notes |
|---|---|---|---|
| Verify staging schema | List remote migration history; query installed `plpgsql_check` extension version; run `supabase db diff`; possibly invoke Python verifier. | Intended read-only | The verifier compares a schema diff against a repository migration. It does not itself connect to the database. |
| Remove obsolete remote-only migration history | Re-list migrations; identify entries present remotely but absent locally; run `supabase migration repair --status reverted` for those IDs. | **Remote migration-history mutation** | Changes migration bookkeeping; not a schema reset, but still changes remote DB metadata. |
| Mark repository migrations as applied | Re-list migrations; identify local migrations absent remotely; run `supabase migration repair --status applied`. | **Remote migration-history mutation** | Marks migrations applied without running their SQL. Correctness relies on the prior schema-equivalence check and operator review. |
| Verify migration history | List history; `supabase db push --dry-run`; verify extension version; diff schema; invoke verifier if the diff is not clean. | Intended read-only verification | A clean result is the workflow's success condition; this does not independently prove application data integrity or backup recoverability. |

The workflow does not contain `supabase db reset` or `supabase db push` without `--dry-run`. It does contain two `supabase migration repair` commands that change remote migration history.

## 4. Script call graph and verifier behavior

`scripts/verify-staging-public-schema.py` is called from the initial diff step when the diff is not the exact clean marker, and again during final verification if the final diff is not clean.

The script:
1. Reads a diff file, defaulting to `/tmp/staging-public-schema-diff.log` unless a path argument is supplied.
2. Reads `supabase/migrations/20260930130000_p15_t239_match_phone_source_fix.sql`.
3. Extracts the `public.match_import_customers` function contract from both files, comparing arguments, return table, search path, and function body after whitespace normalization/lowercasing.
4. Removes the expected `plpgsql_check` extension statement, the repository-equivalent function definition, the `check_function_bodies` session-setting preamble, and comment lines.
5. Fails if the function is missing from either source, contracts differ, or any unexpected public-schema diff remains.

This script performs local file reads and comparisons only; it does not execute SQL or connect to Supabase. Its expected migration is a hardcoded path, so any change to the known exception requires corresponding reviewed updates. The verifier's equivalence comparison is textual/normalized, not a formal proof of semantic equivalence.

## 5. Secrets, variables, and related workflow paths

| Source | Reference in repair workflow | Status |
|---|---|---|
| GitHub Actions secret `STAGING_SUPABASE_DB_PASSWORD` | Database connection in each remote step | Referenced; value and validity not checked |
| Hardcoded project ID `mijbpvgxrxjaalimyqgm` | URL username and workflow env | Confirmed in YAML |
| Hardcoded pooler hostname | Database URL in each step | Confirmed in YAML |
| GitHub environment `staging` | Job environment | Declared; reviewer/branch protection settings unverified |
| Local verifier script | `python scripts/verify-staging-public-schema.py` | Confirmed call path |
| Reusable workflow | None declared | No `uses: ./.github/workflows/...` or `workflow_call` in this file |
| Related reset workflow | `controlled-staging-database-reset.yml` is a separate manually dispatched workflow | Separate workflow; it performs a destructive reset, documented in PR #330 |
| Related staging deploy workflow | `deploy-staging.yml` is a separate manually dispatched workflow | It runs `supabase db push` against staging and loads a staging UAT fixture before deploying the staging Worker; it is not called by this repair workflow |

## 6. Safety observations and open questions

- **Confirmed:** project ID and pooler host are hardcoded to staging-specific values; the password reference is staging-named; workflow uses the `staging` environment.
- **Confirmed:** remote migration history can be rewritten by marking migrations `reverted` or `applied`.
- **Confirmed:** marking a migration applied does not run its SQL. The workflow relies on schema equivalence checks to justify that bookkeeping change.
- **Not verified:** GitHub environment reviewers, dispatch authorization, secret validity, artifact/log retention settings, and any organization-level policy controls.
- **Not done:** no workflow run, database connection, migration repair, schema reset, migration application, or deployment.

## 7. Follow-up

AUD-P1-003 should enumerate destructive commands, fallback paths, target overrides, and secret exposure paths across both the reset and repair workflows. Guard design belongs to AUD-P1-004 and requires explicit approval before any workflow edit or test that touches a live database. This document makes no code or workflow changes.
