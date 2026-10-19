# AUD-P1-008 — Deployment-hygiene proposal

**MST task:** AUD-P1-008  
**Phase:** P1 — Safety containment  
**Workstream:** Deployment configuration  
**Status:** Proposal prepared for review; implementation not approved  
**Scope:** Documentation and recommendations only. This change does not edit workflow/configuration files, run deployment or reset workflows, access a database, or change application/runtime behavior.

## 1. Objective

Make deployment and staging operations explicit, reproducible, fail-closed, auditable, and recoverable. Align workflow configuration, operator documentation, and rollback instructions so a staging action cannot be mistaken for production work or run against an unintended target.

## 2. Proposed target boundaries

| Target | Permitted by this proposal | Required safeguards |
|---|---|---|
| Local development | Local checks and disposable local services | Explicit local URLs; no inherited production secrets |
| CI ephemeral environment | Automated checks against services created for that job | Job-scoped credentials; localhost endpoints; teardown on success and failure |
| Staging | Only explicitly approved, staging-scoped operations | Named environment; protected environment approval for destructive actions; explicit project/target identity; preflight and postflight evidence |
| Production | No change authorized by AUD-P1-008 | Separate approval and change plan; never a fallback target for staging scripts |

No workflow should infer its target from an implicit default, whichever credentials happen to be present, or a developer's CLI login. Missing or ambiguous target configuration must stop the operation before any mutating command runs.

## 3. Configuration and workflow hygiene

Before implementation, inventory the workflows, scripts, package commands, Supabase CLI invocations, deployment provider settings, environment variables, and operator documentation that can deploy, reset, migrate, seed, import, or mutate remote state.

For each mutating path, document:
- The exact workflow/script entry point and intended target.
- Required environment variables and how target identity is verified without printing secrets.
- The permissions and credentials used, their scope, and where approval is enforced.
- The commands that mutate state, and the commands that are read-only.
- The expected success evidence and failure behavior.

Proposed controls (not yet implemented):
1. Require an explicit, allow-listed environment/target for all remote mutations; reject blank, unknown, or production targets in staging-only paths.
2. Separate read-only validation from mutating steps. Run preflight checks before any migration, reset, seed, import, or deploy command.
3. Use least-privilege, job/environment-scoped credentials; avoid repository-wide or personal credentials when a narrower identity is available.
4. Pin critical third-party actions and CLI versions to reviewed, reproducible versions/digests where supported; document the update process.
5. Set workflow permissions to the minimum required and gate sensitive staging jobs with the repository's protected-environment approval mechanism where available.
6. Never print tokens, connection strings, full environment dumps, or secret-bearing command output. Record only sanitized target identifiers and outcomes.
7. Ensure cleanup and failure paths do not silently continue after a failed preflight or partially completed destructive step.

## 4. Documentation alignment

Once implementation is separately approved, reconcile these sources against the same target model:
- Workflow YAML and reusable workflows.
- package.json scripts and helper scripts.
- Supabase CLI configuration and migration/test instructions.
- Deployment provider configuration and environment-variable documentation.
- README and operator/runbook instructions for staging deploy, migration, reset, seed/import, verification, and rollback.

Documentation must name the environment explicitly, show safe preflight steps, identify destructive commands, describe required approvals, and distinguish a branch/commit preview from a production deployment. Remove or rewrite ambiguous examples that can accidentally select a remote/default project. Do not remove or rewrite existing configuration until its callers and intended behavior are verified.

## 5. Staging validation plan (only after implementation approval)

Use a disposable or explicitly designated staging target—not production—and capture evidence for each item:
1. **Target identity:** workflow fails closed when target/project identity is missing, malformed, or not on the staging allow-list.
2. **Approval gate:** a protected mutating job cannot proceed before the required approval.
3. **Read-only preflight:** identity, connectivity, migration status, and relevant prerequisites are checked before mutation.
4. **Safe path:** a non-destructive deployment/verification completes against the intended staging target.
5. **Destructive-path protection:** reset/import/migration paths require explicit target identity and the documented approval gate; test guards without executing against production.
6. **Failure behavior:** deliberately fail a preflight in an isolated test and confirm no later mutation step runs.
7. **Postflight:** capture commit SHA, workflow run URL, target/environment label, migration/deployment result, and smoke-test result with secrets redacted.
8. **No cross-environment effects:** verify production configuration and data were not targeted or modified.

A preview URL or successful build alone is not proof that a staging database migration or production deployment occurred.

## 6. Rollback and recovery requirements

Before any approved mutating rollout, write a change-specific rollback plan that identifies:
- The exact change and affected workflow/configuration paths.
- The known-good commit/configuration and how to restore it.
- Whether database changes are involved; schema/data rollback must be handled separately and must not be assumed reversible.
- Backup/snapshot prerequisites and verification, where applicable.
- Stop conditions, responsible approver, and who can execute recovery.
- Post-rollback checks and evidence required to declare recovery complete.

For application/workflow configuration, prefer reverting the reviewed commit or restoring the known-good version. For database migrations, do not promise a generic reverse migration: inspect the migration and data effects, and obtain separate approval and a migration-specific recovery plan. Do not use a staging reset as a rollback shortcut.

## 7. Approval and execution boundary

This proposal does **not** authorize implementation. A separate explicit approval is required before changing workflow permissions, protected environments, deployment targets, secrets handling, CLI commands, migration/reset/import behavior, or provider configuration. Any production action requires its own explicit authorization and must not be inferred from approval to improve staging hygiene.

## 8. Acceptance checklist

- [ ] Inventory all deployment/staging mutating entry points and their intended targets.
- [ ] No implicit/default target can be used for a remote mutation.
- [ ] Staging-only paths reject production and unknown targets before mutation.
- [ ] Sensitive jobs use least privilege and required approval gates.
- [ ] Workflow permissions and action/CLI versions are documented and reviewed.
- [ ] README/runbooks/scripts/configuration agree on commands and target names.
- [ ] Staging validation evidence covers positive, negative, and failure-path cases.
- [ ] A change-specific rollback/recovery plan is approved before rollout.
- [ ] Production was not targeted by validation.
- [ ] Evidence links, commit SHA, and approval decision are recorded in the MST.

## 9. Current evidence and remaining work

This PR supplies the requested proposal and acceptance criteria only. It does not claim that the repository has been fully inventoried at command-level, that any guard has been implemented, that staging validation has run, or that rollback has been tested. Those are implementation/validation deliverables for a separately approved follow-up.

**Recommended MST status after this proposal is reviewed:** In Progress — proposal prepared; implementation and staging validation pending approval. Do not mark AUD-P1-008 Complete until all applicable acceptance items have evidence and the MST row links that evidence.
