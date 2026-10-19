# Audit Baseline and Initial Finding Register

**Recorded:** 2026-10-20  
**Status:** Preliminary baseline published for review. AUD-P0-012 is **not complete** until AUD-P0-010 security scans are executed and their results are added, and the dependent audit evidence is accepted.

## 1. Scope and source baseline

- Repository: https://github.com/imranmirzadubai-dot/ecommerce-operations
- Baseline branch: `main`
- Exact source commit: `40f03c22332a2b8653c7e78b609b4d891c33ce18`
- Audit comparison snapshot: `3a8e88d6d2e3b06a6a09cf911143bba29357da83`
- Main was 29 commits ahead of the snapshot and 0 commits behind at the time of comparison.
- This is a static source/CI inventory with referenced CI results. It is not a claim that production or staging runtime state has been independently verified.

## 2. Baseline execution evidence

The existing GitHub Actions CI run [#39319087121](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/39319087121), on a documentation-only audit PR based on the target source baseline, reported successful steps for:

| Check | Command / operation | Result |
|---|---|---|
| Dependency installation | `npm ci` | Pass |
| Lint | `npm run lint` | Pass |
| Typecheck | `npm run typecheck` | Pass |
| Unit tests | `npm test` | Pass |
| Source graph | `npm run check:source-graph` | Pass |
| Build | `npm run build` | Pass |
| E2E | `npm run e2e` | Pass |
| Isolated database job | `supabase db start`, local `supabase db reset`, configured pgTAP suite | Pass |

CI used Node.js major version 24 and Supabase CLI 2.105.0 for the database job. The connected tooling exposed step statuses but not full downloadable job logs, so this report does not invent exact test counts, warning counts, package vulnerability counts, or assertion totals.

## 3. Repository inventory snapshot

Counts from the recursive Git tree at the baseline commit:

- 148 migration files under `supabase/migrations/`
- 168 entries under `supabase/tests/database/` (includes six temporary-looking `.tmp3`–`.tmp8` files; not all entries necessarily represent runnable tests)
- 47 unit-test files under `tests/unit/`
- 7 E2E test files under `tests/e2e/`
- 36 GitHub Actions workflow YAML files under `.github/workflows/`
- 55 open pull requests at inventory time

Configuration includes `.env.example` with blank Supabase URL/publishable-key placeholders, `.gitignore` rules for local environment files, and `supabase/config.toml` for local Auth/database configuration. Production and staging deployment workflows, controlled staging reset, and staging migration-history repair workflows are present.

## 4. Initial finding register

| ID | Priority | Finding / observation | Evidence | Status / next action |
|---|---|---|---|---|
| F-001 | P0 | Dependency vulnerability scan not executed; counts unknown. | AUD-P0-010 assessment | Open. Run `npm audit` against committed lockfile in trusted CI; record tool/runtime and redacted severity counts. |
| F-002 | P0 | Full Git-history secret scan not executed; counts unknown. | AUD-P0-010 assessment | Open. Run a full-history scanner with secret redaction; record version, refs covered, counts only. |
| F-003 | P1 | Six temporary-looking SQL files are present in the DB-test directory. | Repository tree | Open. Confirm intent/ownership; do not delete without review. |
| F-004 | P1 | Staging deploy workflow uses Supabase CLI `latest`. | `.github/workflows/deploy-staging.yml` | Open. Pin a tested version in a separate reviewed change. |
| F-005 | P1 | Privileged staging reset and migration-repair workflows can perform destructive database or migration-history operations. | `controlled-staging-database-reset.yml`, `repair-staging-migration-history.yml` | Open for detailed workflow security review under AUD-P1 tasks. Do not trigger as part of this baseline. |
| F-006 | P1 | Large open-PR backlog makes integration state and duplicate audit documentation hard to reason about. | GitHub open PR listing (55 at snapshot time) | Open. Triage current PRs; do not merge or close without review/approval. |
| F-007 | P2 | Database-test numbering overlaps and temporary-looking files reduce test discoverability. | Repository tree | Open. Review naming and test discovery separately. |
| F-008 | P2 | Exact npm patch version, detailed test counts, raw logs, and test assertion counts were not available through the connected tool summaries. | CI job step summaries | Evidence limitation. Obtain and retain logs/artifacts where possible; do not infer counts. |

No security scan is treated as clean by default. Baseline command passes are distinguished from security findings that remain unknown because the checks have not run.

## 5. Referenced task evidence

- AUD-P0-001 — baseline metadata: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-001-baseline/docs/audit/AUD-P0-001-BASELINE.md
- AUD-P0-002 — snapshot comparison: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-002-snapshot-comparison/docs/audit/AUD-P0-002-SNAPSHOT-COMPARISON.md
- AUD-P0-003 — npm ci baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-003-npm-ci-baseline/docs/audit/AUD-P0-003-NPM-CI-BASELINE.md
- AUD-P0-004 — lint baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-004-lint-baseline/docs/audit/AUD-P0-004-LINT-BASELINE.md
- AUD-P0-005 — typecheck baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-005-typecheck-baseline/docs/audit/AUD-P0-005-TYPECHECK-BASELINE.md
- AUD-P0-006 — unit-test baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-006-unit-test-baseline/docs/audit/AUD-P0-006-UNIT-TEST-BASELINE.md
- AUD-P0-007 — source-graph baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-007-source-graph-baseline/docs/audit/AUD-P0-007-SOURCE-GRAPH-BASELINE.md
- AUD-P0-008 — build baseline: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-008-build-baseline/docs/audit/AUD-P0-008-BUILD-BASELINE.md
- AUD-P0-009 — isolated database tests: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-009-isolated-db-tests/docs/audit/AUD-P0-009-ISOLATED-DB-TESTS.md
- AUD-P0-010 — security scan assessment/blocker: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-010-security-scan-assessment/docs/audit/AUD-P0-010-SECURITY-SCAN-ASSESSMENT.md
- AUD-P0-011 — repository inventory: https://github.com/imranmirzadubai-dot/ecommerce-operations/blob/audit/aud-p0-011-repository-inventory/docs/audit/AUD-P0-011-REPOSITORY-INVENTORY.md

These evidence documents currently reside on their respective unmerged audit branches. The links are references for review, not proof that each report has been merged into main.

## 6. Completion gate and safety

AUD-P0-012 remains pending final acceptance until:
1. AUD-P0-010 executes both scans and records sanitized outputs and tool versions.
2. Audit evidence is reviewed and accepted; branch-only reports are not treated as merged mainline documentation.
3. Any baseline failure is explicitly separated from newly introduced failures.

No application code, dependency lockfile, database schema/data, production/staging environment, or deployment was changed by this documentation task. No secrets were accessed or included.
