# AUD-P1-004 — Fail-Closed Staging Guard Proposal

**Status:** Proposal only; not implemented
**Scope:** Staging database reset, migration-history repair, and staging deployment workflows
**Safety boundary:** Documentation-only design review. No workflow was run, no database was contacted, and no schema, data, secret, deployment, or workflow was changed.

## Objective

Make staging workflows stop before remote commands whenever target identity, source ref, credentials, or required safety conditions are missing, malformed, unexpected, or contradictory.

## Current observations

- The workflows use a GitHub environment named staging and a hard-coded staging Supabase project ID: mijbpvgxrxjaalimyqgm.
- The reset workflow contains a remote destructive reset; its backup option can be disabled and there is no automatic restore step.
- The migration repair workflow changes remote migration-history bookkeeping.
- The staging deploy workflow applies migrations, loads a staging UAT fixture, and deploys a staging Worker.
- The staging deploy workflow checks out the dispatch-selected ref. Whether dispatch permissions and environment protections restrict this sufficiently is unverified.
- Environment reviewers, branch rules, and secret validity have not been verified.
- These observations do not prove production is currently reachable; they identify controls that should be enforced and tested.

## Proposed controls

### 1. Exact target identity checks

Before any remote database command, validate all of the following against reviewed staging values:
- GitHub environment equals staging.
- Supabase project ID equals mijbpvgxrxjaalimyqgm.
- Parsed database URL host and port match the approved staging pooler exactly.
- Database URL, project ID, Supabase URL, and app environment agree with one another.
- Worker environment and name match the approved staging Worker, never the production Worker.
- Missing, malformed, unexpected, or conflicting values stop the job.
- Do not use substring matching as the sole guard, and never print database URLs or secret values.

### 2. Validate before exposing credentials

- Run static checks before loading credentials.
- Validate source ref and environment before secret-bearing steps.
- Load only minimum staging secrets after preflight passes.
- Check required secrets are non-empty without echoing values.
- Do not run untrusted branch code while staging secrets are available.
- Pin third-party actions to reviewed full commit SHAs as separate supply-chain hardening.
- Use least-privilege permissions and protected GitHub environment approvals for destructive operations.

### 3. Restrict checkout refs

- Reset and migration-repair workflows should check out a fixed reviewed main ref or an immutable reviewed commit.
- Staging deploy should use a fixed reviewed ref or an explicitly approved candidate ref.
- If arbitrary branch deploys are required, use a non-secret, non-mutating preview first and a protected promotion step before staging credentials become available.
- Reject refs not explicitly permitted. Do not assume the staging environment alone prevents untrusted workflow code from running.

### 4. Layered reset safeguards

- Require exact typed confirmation: RESET STAGING, plus a separate input identifying the expected staging project.
- Require backup creation; do not offer a routine dispatch option that disables backup.
- Verify the backup artifact was created and uploaded before reset.
- Run a final target-identity guard immediately before the destructive command.
- If backup creation, upload, or verification fails, stop; reset must not start.
- Document recovery steps and authorization. Do not claim a backup is recoverable until restore has been tested in an isolated environment.

### 5. Migration-history repair safeguards

- Require a protected environment and reviewer approval.
- Produce a read-only plan listing exact migration versions and intended status changes before mutation.
- Revalidate target identity immediately before every repair command.
- Reject empty, malformed, unexpected, or overly broad migration-version lists.
- Capture before/after history and stop if observed state differs from the approved plan.
- Keep dry-run and schema-diff checks as verification; migration bookkeeping repair is not schema execution.
- Do not claim automatic rollback unless a rollback procedure has been tested.

### 6. Staging deployment safeguards

- Run lint, typecheck, tests, build, source/ref checks, and configuration checks before remote database access.
- Ensure all steps receiving staging secrets run only reviewed code from an approved ref.
- Add final exact-target checks before database migration, fixture loading, and Worker deployment.
- Keep migration, fixture load, and Worker deployment as separate gated steps with stop-on-failure behavior.
- Never use production credentials or production environment names in staging jobs.
- Make fixture loading idempotent or detect existing fixture records; any cleanup must be scoped to uniquely tagged test records and separately reviewed.

## Dummy-input validation matrix

These are proposed local/static tests only. They must not connect to Supabase, Cloudflare, or any remote service.

| Case | Input condition | Expected result |
|---|---|---|
| G-01 | Exact approved staging project, host, URL, Worker, and environment | Preflight passes |
| G-02 | Production project ID | Fail before secret use and remote command |
| G-03 | Production database host or production Worker name | Fail closed |
| G-04 | Missing project ID, URL, environment, or required secret | Fail closed; no secret values logged |
| G-05 | Malformed database URL, unexpected port, or unapproved host | Fail closed |
| G-06 | Project ID conflicts with URL hostname | Fail closed |
| G-07 | Ref is not in the allowlist | Fail before credentials are exposed |
| G-08 | Backup disabled or backup creation/upload/verification fails | Reset never starts |
| G-09 | Confirmation differs by case, whitespace, or spelling | Reset never starts |
| G-10 | Migration plan is empty or includes malformed/unapproved versions | Repair never starts |
| G-11 | Target identity changes before mutation | Final guard blocks mutation |
| G-12 | Any preceding check fails | Dependent mutation/deploy steps remain skipped |

Use dummy values and replace remote commands with stubs that record whether they were called. Assert that rejected inputs never invoke a remote-command stub. Do not test negative cases against live databases.

## Implementation sequence — separate approval required

1. Verify GitHub environment reviewers, branch rules, workflow dispatch permissions, and secret scoping using read-only settings review.
2. Agree the allowed deploy-ref policy and whether backups must be mandatory.
3. Implement reusable fail-closed preflight validation and dummy-input unit tests.
4. Add preflight gates to reset workflow and independently review the diff.
5. Add preflight gates to migration repair and independently review the diff.
6. Add ref restrictions and final target guards to staging deploy and independently review the diff.
7. Validate CI and static tests. Do not run destructive workflows as tests.
8. Obtain explicit approval for any future live staging smoke test, specifying workflow, target, action, and time window.

## Acceptance criteria

- Every absent, incorrect, or conflicting target input fails closed.
- No rejected dummy-input case invokes a remote-command stub.
- No secret values appear in logs or test output.
- Secret-bearing staging steps cannot run from unapproved refs.
- Reset cannot proceed without verified backup and exact confirmation.
- Production identifiers are rejected before credentials are loaded.
- Tests require no production or staging database access.
- Implementation is reviewed in a separate PR and is not merged or executed without authorization.

## Explicit exclusions

This proposal does not authorize workflow edits, live database access, database reset, migration repair, staging deployment, production access, secret changes, PR merge, or release. Those actions require separate review and authorization.