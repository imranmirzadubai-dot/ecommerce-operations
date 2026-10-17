# Initial Audit Finding Register

**As of:** 2026-10-13  
**Method:** Read-only review; items below are observations or hypotheses, not all confirmed defects. Do not treat a concern as a proven vulnerability without targeted evidence.

| ID | Finding / concern | Current status | Evidence / next verification |
|---|---|---|---|
| F-001 | Date-range filtering may ignore `date_from` when `date_to` is also set. | Unverified hypothesis | Reproduce against relevant query logic and tests; add paired-boundary cases only after approval. |
| F-002 | Search subqueries may truncate at 100 results, and user terms are interpolated into PostgREST `or=(...)`. | Unverified security/correctness concern | Trace query construction and escaping semantics; test safely with representative inputs. |
| F-003 | Wrangler top-level `ENVIRONMENT` is `production` and production Supabase URL/publishable-key values are committed despite comments saying production values are not committed. | Observed configuration/comment inconsistency; impact unverified | Trace each deploy workflow and environment-specific override. Publishable key is not a service-role secret. |
| F-004 | GitHub Actions references may use mutable tags rather than pinned full commit SHAs. | Inventory concern | Inventory every workflow action reference; distinguish official immutable SHA pins from mutable tags. |
| F-005 | Staging reset/repair workflows could target production if secrets/environment wiring is misconfigured. | High-priority unverified safety concern | Read-only trace of workflow triggers, environment protection, project URL sourcing, and reset commands. Do not run a reset or migration against a connected database. |
| F-006 | Command proxy allowlist and SQL authorization guards may not align. | Unverified authorization concern | Trace allowlist, caller identity, SQL guards, and negative authorization tests. |
| F-007 | README references `server/` and `packages/` although repository inventory reportedly shows `.gitkeep` placeholders and primary app code in `worker/index.ts`. | Documentation accuracy concern | Verify current tree and update documentation only through reviewed PR. |
| F-008 | Workflow count, feature-branch triggers, and workflow duplication may create unnecessary operational complexity. | Inventory concern | Map workflow triggers, environments, permissions, and overlapping jobs before proposing changes. |
| F-009 | Test coverage may be thin for Worker integration, accessibility, and responsive behavior. | Partially evidenced | Existing checks passed on PR #328 head; its viewport test only checks the dashboard. Collect broader screen-level evidence. |
| F-010 | Accessibility, performance, backup/recovery, financial concurrency, and import safety have not been fully assessed. | Not assessed | Create scoped evidence-based checks; do not infer safety from unit-test success. |

## Separate blocking audit item

**AUD-P0-010 — secret/dependency security evidence: BLOCKED.** Default-branch searches for `sb_secret`, `service_role`, `PRIVATE KEY`, and `password` returned no matches. This is not a full-history scan. A dedicated full-history secret scan and a detailed authenticated npm advisory report were not completed. `npm ci` reported 9 high-severity vulnerabilities but did not provide the advisory-level evidence captured in this pass. No automated dependency fixes were run.

## Governance

- Do not apply fixes from this register without explicit approval.
- No production DB/schema/data changes, merges, or deployments without separate explicit approval.
- Preserve unresolved status where evidence is incomplete.
- Review each finding against the current main SHA before making a remediation decision.
