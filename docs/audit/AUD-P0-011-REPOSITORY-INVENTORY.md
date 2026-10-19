# AUD-P0-011 — Repository Inventory

**Recorded:** 2026-10-20  
**Status:** Inventory documented from the repository tree and selected configuration files. This is a static inventory, not a complete semantic audit of every file.

## Source baseline

- Repository: https://github.com/imranmirzadubai-dot/ecommerce-operations
- Branch inspected: `main`
- Exact commit: `40f03c22332a2b8653c7e78b609b4d891c33ce18`
- Tree inspection: GitHub recursive tree API at that commit.

## Inventory counts

| Area | Count / observed state |
|---|---:|
| Supabase migration files under `supabase/migrations/` | 148 |
| Database-test directory entries under `supabase/tests/database/` | 168 |
| Unit-test files under `tests/unit/` | 47 |
| E2E test files under `tests/e2e/` | 7 |
| GitHub Actions workflow YAML files under `.github/workflows/` | 36 |
| Open pull requests at inspection time | 55 |
| Environment template | `.env.example` present |
| Supabase local config | `supabase/config.toml` present |
| Production/staging deployment workflows | Present |
| Staging reset and migration-history repair workflows | Present |

Counts are file/tree snapshots, not a claim that every database-test directory entry is a runnable test. The database test directory contains six temporary-looking `061_post_dispatch_allocation_immutability.sql.tmp3` through `.tmp8` files and should be reviewed for intentional retention. The directory also has multiple similarly numbered tests (for example, `003`, `005`, `013`, `019`, `028`, `061`, `087`, `093`, `104`, `117`–`128`); numbering overlap is not itself a failure but makes inventory/navigation less clear.

## Test and migration layout

- Unit tests are in `tests/unit/` and the configured `npm test` command runs `tests/unit/*.test.js` and `tests/unit/*.test.mjs`.
- Browser tests are in `tests/e2e/`; the CI workflow includes the Playwright E2E job.
- SQL database tests are in `supabase/tests/database/`. CI starts an ephemeral Supabase instance, resets that local instance, enables pgTAP, and runs an explicit SQL test list.
- Migrations are timestamped SQL files in `supabase/migrations/`; the latest inspected entries include courier model/creation/edit/assignment, order runtime contract, phone normalization, RLS/security-definer hardening, and matched-customer integrity work.
- The CI workflow also runs lint, typecheck, unit tests, source-graph validation, and build.

## Environment configuration

- `.env.example` contains blank `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` placeholders and warns against placing real secrets in the template.
- `.gitignore` excludes `.env*` and `*.local`, while allowing `.env.example`.
- `supabase/config.toml` configures local Auth and database settings and explicitly says hosted/staging Auth configuration is project-level and secrets do not belong in the file.
- The production deployment workflow hardcodes the production Supabase URL and Cloudflare account ID, requires publishable/secret keys and a Cloudflare token from GitHub secrets, runs quality gates, builds, then deploys the Worker.
- The staging deployment workflow targets a distinct staging Supabase project and Worker name, applies migrations, loads and verifies a named staging UAT fixture, builds, then deploys. It uses Supabase CLI `latest`, which is less reproducible than pinning a tested version.
- The controlled staging reset workflow requires the exact input `RESET STAGING`, validates the staging project/host, starts and resets an ephemeral local database for migration-chain verification, captures a staging backup artifact, then explicitly resets the remote staging project. This is destructive to staging by design and must remain guarded by environment protection, credentials, and explicit operator authorization.
- The staging migration-history repair workflow inspects the remote staging schema and then issues migration-history repair commands. Its manual dispatch and staging environment are important controls; any invocation should be treated as a privileged operation.

No workflow was executed by this inventory task; findings above are from static source inspection only.

## Outstanding pull requests

At inspection time, GitHub returned **55 open PRs**, including active feature/fix PRs and numerous audit-documentation PRs. Relevant open audit PRs include:

- #359 AUD-P0-002 snapshot comparison
- #360 AUD-P0-003 npm-ci baseline
- #361 AUD-P0-004 lint baseline
- #362 AUD-P0-005 typecheck baseline
- #363 AUD-P0-006 unit-test baseline
- #364 AUD-P0-007 source-graph baseline
- #365 AUD-P0-008 build baseline
- #366 AUD-P0-009 isolated database test baseline
- #367 AUD-P0-010 security scan assessment/blocker

Other notable open changes include PR #358 (P17-T291 self-escalation protection), #357 (bounded JSON request bodies), #356 (prevent silently truncated order search matches), and #355/#354 (upstream error sanitization). This is a point-in-time inventory; PR state may change.

Full live list: https://github.com/imranmirzadubai-dot/ecommerce-operations/pulls

## Findings and follow-up

1. **AUD-P0-010 remains incomplete.** Dependency vulnerability and full-history secret scans have not been run; counts are unknown.
2. **Potential test debris:** six `.tmp3`–`.tmp8` files in the database test directory warrant owner review. They were not deleted or modified.
3. **Workflow reproducibility:** staging deployment uses Supabase CLI `latest`; consider pinning a validated version in a separate approved change.
4. **Privileged staging operations:** staging deploy, reset, and migration repair workflows deserve detailed trigger/permission/environment/target provenance review in AUD-P1 tasks. No such workflows were triggered.
5. **Open PR backlog:** 55 open PRs means integration state requires triage. No PRs were merged or closed as part of this inventory.
6. **Static scope limit:** this inventory does not establish that all environment secrets are configured, all RLS policies are correct, or production/staging state matches migrations. Those require separate evidence-backed checks.

## Safety

Documentation only. No code, migrations, database schema/data, GitHub secrets, or deployments were changed.
