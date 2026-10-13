# AUD-P1-005 — GitHub Actions Pinning and Supply-Chain Hardening Plan

**Status:** Read-only inventory and proposal; no workflow changes implemented
**Safety boundary:** No workflow was executed, no secret was read, and no database or deployment was accessed.

## Objective

Reduce the risk of a third-party GitHub Action tag being moved to different code after review. Establish a reproducible, reviewable process for pinning actions to full commit SHAs without changing workflow behavior in the same change.

## Verified examples from the reviewed staging workflows

| Workflow | Action reference observed | Risk / note |
|---|---|---|
| `.github/workflows/controlled-staging-database-reset.yml` | `actions/checkout@v4` (reported in the read-only workflow review) | Mutable major-version tag; verify exact commit SHA and release provenance before pinning |
| `.github/workflows/controlled-staging-database-reset.yml` | `supabase/setup-cli@v1` (reported in the read-only workflow review) | Mutable major-version tag; verify exact commit SHA and release provenance before pinning |
| `.github/workflows/controlled-staging-database-reset.yml` | `actions/upload-artifact@v4` (reported in the read-only workflow review) | Mutable major-version tag; verify exact commit SHA and release provenance before pinning |
| `.github/workflows/repair-staging-migration-history.yml` | `actions/checkout@v4` | Runs in a workflow that receives a staging database password and changes remote migration-history bookkeeping |
| `.github/workflows/repair-staging-migration-history.yml` | `supabase/setup-cli@v1` | CLI setup action executes in a credential-bearing workflow |
| `.github/workflows/deploy-staging.yml` | `actions/checkout@v4` | Selected branch is checked out; branch restriction is a separate high-priority control |
| `.github/workflows/deploy-staging.yml` | `actions/setup-node@v4` | Dependency/tool setup action in a workflow with staging secrets |
| `.github/workflows/deploy-staging.yml` | `supabase/setup-cli@v1` | CLI setup action in a workflow that applies migrations and loads fixtures |

**Scope note:** This is a targeted inventory of references confirmed in the reviewed workflows, not a repository-wide exhaustive action inventory. No exact commit SHA is asserted here because each candidate must be checked against its upstream release and provenance at implementation time.

## Proposed policy

1. Pin every third-party action used by secret-bearing or mutation-capable workflows to a full 40-character commit SHA.
2. Keep a short adjacent comment naming the upstream release/tag corresponding to the pinned SHA, and link to the upstream repository/release for review traceability.
3. Verify the SHA against the canonical upstream repository; do not copy a SHA from an untrusted fork, search snippet, or unverified blog.
4. Review action source and release provenance before adopting a new major version. Treat action upgrades as explicit dependency updates, not incidental refactoring.
5. Apply pinning in a dedicated PR with no functional workflow changes, then validate YAML/static checks and inspect the complete diff.
6. Consider repository-level policy or a linter that rejects unpinned action references, with a documented exception process for local actions and actions that cannot be pinned.
7. Keep `permissions` least-privilege and continue to restrict secret-bearing workflows to reviewed refs. SHA pinning does not replace these controls.
8. Do not treat pinning the action as pinning the tool it installs. Independently pin CLI/tool versions where supported; avoid `latest` in repeatable deployment workflows.

## Review and validation checklist

- [ ] Enumerate all workflow files and every `uses:` reference, including reusable workflows and nested composite actions.
- [ ] Record action owner/repository, current ref, workflow, permissions, and whether secrets or mutation commands are present.
- [ ] Verify the proposed full SHA and its upstream release mapping from the canonical source.
- [ ] Inspect action permissions, scripts, and install behavior before pinning.
- [ ] Preserve workflow semantics; make no simultaneous reset, deployment, migration, or credential changes.
- [ ] Run static YAML and workflow-lint checks only; do not dispatch workflows as a pinning test.
- [ ] Open a separate PR and require review before merge.

## Priority

Start with workflows that receive credentials or can mutate infrastructure: staging reset, staging migration repair, staging deployment, and production deployment workflows. Then inventory and pin remaining workflow actions in a separate controlled batch.

## Explicit exclusions

This document does not change any workflow, pin any action, rotate secrets, run CI workflows manually, contact Supabase or Cloudflare, reset a database, repair migration history, deploy code, or merge a PR. Those actions require separate implementation review and authorization.