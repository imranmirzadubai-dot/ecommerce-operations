# Ecommerce Operations — Audit Baseline

**Prepared:** 2026-10-13  
**Repository:** `imranmirzadubai-dot/ecommerce-operations`  
**Baseline branch:** `main`  
**Baseline commit:** `3a8e88d6d2e3b06a6a09cf911143bba29357da83`  
**Scope:** Read-only repository, CI, configuration, and inventory review. This document records evidence and open questions; it does not authorize or perform application fixes.

## Executive summary

The baseline commit was signed/verified and the audit snapshot compared equal to `main` (0 commits ahead/behind; 0 files changed). CI evidence from run [38356571795](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/38356571795) is green for the reviewed PR head `9737b7b64b949d7fb8201fa77096627e05ad39ad`; that SHA is **not** the baseline `main` SHA, so the run is not represented as a main-branch verification.

Observed checks on the reviewed PR head:
- `npm ci`: passed; 196 packages added, 197 audited. npm reported 9 high-severity vulnerabilities; advisory details were not captured in this audit pass.
- `npm run lint`: passed.
- `npm run typecheck`: passed.
- `npm test`: 149 passed, 0 failed/cancelled/skipped/todo.
- `npm run build`: passed.
- `npm run check:source-graph`: passed; 49 source files, no duplicate logical stems or circular imports.
- Isolated CI database checks: 64 SQL files / 702 tests passed. The database reset occurred only in the ephemeral GitHub-hosted CI environment, not against connected staging or production projects.

## Runtime and configuration

Repository scripts include `dev`, `build`, `typecheck`, `lint`, `test`, `check:source-graph`, `preview`, `deploy`, `cf-typegen`, `e2e`, and `e2e:install`. The application uses React 19, TypeScript 6, Vite 8, Cloudflare Workers, Supabase PostgreSQL/Auth, and GitHub Actions.

The Wrangler configuration contains top-level `ENVIRONMENT: production` and production Supabase URL/publishable-key values in `vars`, while nearby comments say production values are not committed. This is a configuration/comment consistency concern to review. A Supabase publishable key is not a service-role secret; no key values are reproduced here.

Connected project status observed during the audit:
- Production Supabase project `lltcviwgklwulicjtxnx`: ACTIVE_HEALTHY.
- Staging Supabase project `mijbpvgxrxjaalimyqgm`: ACTIVE_HEALTHY.

These status observations do not establish that application workflows target the intended environment or that backups/restores are proven.

## Security and execution constraints

- AUD-P0-010 remains **BLOCKED**. Default-branch code searches for `sb_secret`, `service_role`, `PRIVATE KEY`, and `password` returned no matches, but this is not a full-history secret scan and does not establish that secrets are absent.
- A dedicated full-history secret scanner and an authenticated, detailed `npm audit` report were not available in this pass. Do not mark the repository as secret-clean or the dependency audit as resolved.
- Staging workflow secret existence/validity has not been verified: `CLOUDFLARE_API_TOKEN`, `STAGING_SUPABASE_PUBLISHABLE_KEY`, and `STAGING_SUPABASE_DB_PASSWORD`. Secret values must never be pasted into chat or audit documents.
- No production database/schema/data changes, merges, or deployments are authorized by this audit.
- No dependency auto-fixes, migration changes, workflow changes, or application fixes were applied.

## Open pull requests and UI evidence

- [PR #314 — architecture diagrams](https://github.com/imranmirzadubai-dot/ecommerce-operations/pull/314): open; checks passed; not approved for merge.
- [PR #315 — runtime migration reconciliation](https://github.com/imranmirzadubai-dot/ecommerce-operations/pull/315): draft/open; checks passed; not approved for merge.
- [PR #328 — responsive acceptance test](https://github.com/imranmirzadubai-dot/ecommerce-operations/pull/328): draft/open/unmerged. CI passed on its head, but the viewport test only checks the dashboard and does not prove all screens are free of navigation/content overlap. Visual evidence still needs review.

## Inventory snapshot

The read-only inventory recorded:
- 35 YAML workflow files, plus `ecommerce-audit.md` and `ecommerce-audit.lock.yml` in `.github/workflows`.
- 146 SQL migration files.
- 161 SQL files under `supabase/tests/database`.
- 28 open pull requests at inventory time.

Inventory is not a workflow-safety assessment. See [FINDINGS.md](./FINDINGS.md) for the initial finding register and [INVENTORY.md](./INVENTORY.md) for inventory details.

## Evidence links

- [Main repository](https://github.com/imranmirzadubai-dot/ecommerce-operations)
- [Workflow inventory](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/.github/workflows)
- [SQL migrations](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/supabase/migrations)
- [Database tests](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/supabase/tests/database)
- [Open pull requests](https://github.com/imranmirzadubai-dot/ecommerce-operations/pulls)
- [CI run 38356571795](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/38356571795)

## Status

This is an initial baseline, not a final security certification. Findings remain open until supported by targeted reproduction, documented remediation, and retesting. Blocked checks must remain explicitly blocked rather than being reported as passed.
