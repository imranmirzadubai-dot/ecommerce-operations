# AUD-P0-001 — Baseline & Environment Record

**Recorded:** 2026-10-20  
**Status:** In progress — remote repository facts verified; local runtime versions still require measurement.  
**Task:** Record repository URL, target branch, exact current SHA, date, Node/npm, Supabase CLI and relevant tool versions.

## Repository baseline

- Repository: https://github.com/imranmirzadubai-dot/ecommerce-operations
- Target branch: `main`
- Exact `main` SHA observed on 2026-10-20: `40f03c22332a2b8653c7e78b609b4d891c33ce18`
- Recorded audit snapshot SHA: `3a8e88d6d2e3b06a6a09cf911143bba29357da83`
- Snapshot and current `main` are different; later audit tasks must compare findings against the current baseline and not assume the snapshot is current.
- Package manifest: `package.json`; lockfile: `package-lock.json` (lockfileVersion 3).
- Supabase local project config: `supabase/config.toml`; configured local project ID is `ecommerce-operations`; configured database major version is 17.

## Toolchain versions: repository/CI configuration

| Tool | Version or setting | Evidence |
|---|---|---|
| Node.js in CI | 24 | `.github/workflows/ci.yml`, `actions/setup-node@v4`, `node-version: 24` |
| Supabase CLI in CI | 2.105.0 | `.github/workflows/ci.yml`, `supabase/setup-cli@v1`, `version: 2.105.0` |
| npm | Not pinned to an exact version in repository workflow | CI runs `npm ci`; npm version depends on the Node 24 runner image |
| Playwright test package | 1.55.0 | `package-lock.json`; package script also invokes `@playwright/test@1.55.0` |
| TypeScript | `~6.0.2` declared | `package.json` |
| Vite | `^8.2.2` declared | `package.json` |
| Wrangler | `^4.130.0` declared | `package.json` |

## Verification limits and next action

This record was assembled from read-only GitHub repository metadata and tracked files. No shell/checkout runtime is exposed through the current GitHub connector, so the actual local `node --version`, `npm --version`, and `supabase --version` outputs have **not** been measured. Do not represent the CI configuration as proof of locally installed versions.

To close AUD-P0-001, capture those three command outputs in the intended development environment (or a controlled CI run), note the OS/runtime context, and append the results here. Until then this task remains **In progress**, not complete.

## Safety

- No application code, database schema, migrations, or production data were changed.
- No database reset, migration push, deployment, or application test command was run.
- The audit branch was created from the verified `main` SHA above.


## Additional controlled CI evidence (2026-10-19)

A successful GitHub Actions CI run (run ID `39319087121`) was inspected read-only. It ran on GitHub-hosted `ubuntu-24.04`, Ubuntu `24.04.5 LTS`, runner image version `20261012.334.1`, runner version `2.337.0`. The run checked out commit `55df5c4bad1d2028c4d6bec276287e27f1e15c13` (the AUD-P0-002 report commit), not the exact `main` SHA recorded above.

The CI workflow configuration confirms Node.js major version 24 and Supabase CLI version 2.105.0 are requested. The captured job logs did not print the actual `node --version`, `npm --version`, or `supabase --version` outputs, so these exact runtime outputs remain unverified. The run's successful status does not fill that evidence gap. No new workflow was triggered and no shell command was run by this assistant.
