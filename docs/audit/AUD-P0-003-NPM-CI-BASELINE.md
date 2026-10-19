# AUD-P0-003 — npm ci Baseline

**Recorded:** 2026-10-20  
**Status:** Verified pass in CI; task evidence documented.  
**Dependency:** AUD-P0-001 baseline metadata recorded.

## Execution evidence

- Repository: https://github.com/imranmirzadubai-dot/ecommerce-operations
- Target source baseline: `main` at `40f03c22332a2b8653c7e78b609b4d891c33ce18`
- CI evidence: [CI run #39319087121](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/39319087121)
- CI event: pull request #359, documentation-only branch based on the verified `main` commit.
- Runner: GitHub Actions `ubuntu-latest`.
- Node setup: `actions/setup-node@v4`, configured with Node.js major version 24 and npm cache.
- Command: `npm ci`
- Observed step result: **completed / success** in the quality job. The same CI run also started the E2E job's `npm ci` step; the quality-job step is the evidence used for this task.
- Exit status: GitHub Actions reports the step successful (effective exit code 0).
- Dependency manifest and lockfile: `package.json` and `package-lock.json`, lockfileVersion 3.

## Interpretation and limits

The lockfile-driven clean dependency installation passed in the controlled CI environment. This supports reproducible installation for this commit under the configured Node 24 CI setup.

The GitHub connector did not expose downloadable step logs at the time of inspection, so the exact npm patch version and verbose package-by-package install output are not recorded here. Do not infer a specific npm version from the Node major version alone. This is a CI baseline result, not a claim that `npm ci` was executed on the user's local computer.

## Safety

- `npm ci` ran in an ephemeral GitHub Actions runner.
- No application behavior was changed by this task.
- No production database connection, reset, migration, or deployment was performed.
- No dependencies were added or updated in the repository; the lockfile was consumed by CI as committed.
