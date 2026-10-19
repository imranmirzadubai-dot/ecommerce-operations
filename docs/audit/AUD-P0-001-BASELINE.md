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
