# Audit Baseline — E-Commerce Operations

**Status:** BLOCKED / INCOMPLETE — do not use this report as a release sign-off  
**Audit snapshot:** `3a8e88d6d2e3b06a6a09cf911143bba29357da83`  
**Snapshot commit:** [GitHub commit](https://github.com/imranmirzadubai-dot/ecommerce-operations/commit/3a8e88d6d2e3b06a6a09cf911143bba29357da83)  
**Branch created for this baseline:** `audit/baseline`  
**Date:** 2026-10-13

## 1. Source baseline

- The supplied ZIP was inspected. It does not include `.git` metadata, so its own HEAD, branch and commit cannot be independently recovered from the archive.
- The supplied audit plan identifies the intended snapshot as `3a8e88d6d2e3b06a6a09cf911143bba29357da83`. GitHub confirms that SHA exists and is the merge commit for PR #327.
- Before treating the ZIP as the exact audited snapshot, compare its tracked-file contents with that commit. This has not yet been completed.
- The repository's CI workflow specifies Node.js 24. The local audit runtime reports Node.js 22.16.0 and npm 10.9.2.

## 2. Baseline command results

| Check | Result | Evidence / limitation |
|---|---|---|
| `npm ci` | **BLOCKED** | Failed with EACCES while trying to create `node_modules` in the extracted workspace. Dependencies were not cleanly installed. |
| `npm run lint` | **BLOCKED** | ESLint could not run; the existing executable returned permission denied. No valid lint result. |
| `npm run typecheck` | **BLOCKED / INVALID BASELINE** | Missing `vite/client` and `node` type definitions; dependency installation had not succeeded. |
| `npm test` | **ENVIRONMENT-MISMATCH RESULT** | 130 tests discovered: 123 passed, 7 failed. At least one failure is a Node.js TypeScript-module loading error (`ERR_UNKNOWN_FILE_EXTENSION`) under Node 22.16.0. Since CI specifies Node 24 and dependencies were not cleanly installed, this is not a trustworthy application defect count. Rerun in a writable workspace with Node 24 after `npm ci`. |
| `npm run build` | **BLOCKED / INVALID BASELINE** | TypeScript type definitions were missing and the workspace denied writes under `node_modules`. |
| `npm run check:source-graph` | **PASS** | `ARCH-005 source graph guard passed; 49 source files checked; no duplicate logical stems or circular imports.` |
| Local Supabase database tests | **NOT RUN** | Supabase CLI/Docker baseline has not been established. Do not use production. |
| `npm audit` | **NOT RUN** | Requires a clean dependency installation and registry access. |
| Full-history secret scan | **NOT RUN** | ZIP has no Git history; scan the repository history in a proper clone. Do not print secret values. |

## 3. Initial verified observations (not yet full findings)

1. `wrangler.jsonc` contains top-level `ENVIRONMENT: production` and a Supabase project URL plus a publishable key. Its trailing comment says production values are supplied by deployment configuration/secrets and are not committed. This is a confirmed configuration/documentation contradiction requiring review. A Supabase publishable key is not equivalent to a service-role secret; assess exposure and environment selection separately. No deployment was run.
2. `.github/workflows/ci.yml` specifies Node.js 24, confirming that the local Node 22 runtime is not an environment match.
3. The source graph check passes for 49 source files.
4. The initial static findings in the supplied remediation plan remain **suspected until independently reproduced**. No functional, security or database finding has been marked fixed or closed in this baseline.

## 4. Production safety

- No production database, Cloudflare Worker, secrets, or configuration was changed.
- No database reset or migration was run.
- No deployment was run.
- The local unit-test command did not contact production by design; the clean isolation status of all future tests must be verified before execution.

## 5. Required next actions to complete Phase 0

1. Obtain a writable workspace and a full Git clone at the exact audited commit.
2. Use Node.js 24 as specified by CI.
3. Run `npm ci` successfully.
4. Rerun lint, typecheck, unit tests, build and source-graph check; retain complete output and versions.
5. Start an isolated local Supabase instance only if Docker/Supabase CLI are available; run database tests against that local instance.
6. Run `npm audit` and a full-history secret scan in the clone, reporting counts and finding IDs only (never secret values).
7. Compare the ZIP to the target commit and record any differences.
8. Update this baseline with final results. Then stop and report Phase 0 results before Phase 1, as required by the remediation plan.

**Conclusion:** Phase 0 is not complete. The only clean pass currently established is the source-graph guard. All other checks must be rerun in a matching, writable environment before any suspected finding is fixed.
