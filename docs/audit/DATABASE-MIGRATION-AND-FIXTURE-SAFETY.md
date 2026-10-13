# Database Migration and Staging Fixture Safety Review

**Audit item:** AUD-P1-007  
**Scope:** Read-only review of the staging migration and P15-T230 synthetic UAT fixture path.  
**Review basis:** Current `main` versions of `.github/workflows/deploy-staging.yml`, `fixtures/staging/P15-T230-UAT-FIXTURE.sql`, and the reviewed migration `supabase/migrations/20260930130000_p15_t239_match_phone_source_fix.sql`.  
**Execution boundary:** No SQL was executed. No database was contacted or changed. No workflow, migration, fixture, application code, or deployment configuration was modified.

## Executive summary

The staging workflow has useful controls: it uses a staging-specific project ID and Worker environment, stops on shell errors, applies migrations before loading the fixture, invokes `psql` with `ON_ERROR_STOP=1`, and runs fixture count checks. The fixture wraps its work in a transaction and commits only after embedded verification succeeds.

Those controls do not make the complete deployment atomic. The migration push and fixture are separate database operations; successful database changes remain even if later build or Worker deployment steps fail. The fixture also preserves any existing fixture identified by its order-note prefix, then validates expected counts. That is safer for immutable COD history than blindly rebuilding, but a partial/stale fixture can cause the workflow to fail without repairing itself.

This document records findings and recommended acceptance criteria only. It does not authorize or implement fixes.

## Observed workflow sequence

From `.github/workflows/deploy-staging.yml`:

1. Manual `workflow_dispatch`; job uses GitHub environment `staging`.
2. Checks out `${{ github.ref_name }}`, not a fixed branch.
3. Checks staging environment variables and expected Worker configuration.
4. Runs lint, typecheck, and unit tests.
5. Runs `supabase db push` against the configured staging database URL.
6. Runs `psql ... -v ON_ERROR_STOP=1 -f fixtures/staging/P15-T230-UAT-FIXTURE.sql`.
7. Runs read-only count queries for synthetic customers, orders, parcels, invoices, and COD obligations.
8. Builds the staging application.
9. Deploys the Worker with `wrangler deploy --env staging`.

**Important boundary:** The migration and fixture operations occur before the final build and Worker deployment. A failure in a later step does not automatically reverse already committed database changes.

## Fixture transaction and rerun behavior

Observed in `fixtures/staging/P15-T230-UAT-FIXTURE.sql`:

- Starts with `begin;` and finishes with `commit;`.
- Requires at least one active profile; otherwise it raises an exception.
- Uses the `P15-T230-` order-note prefix to decide whether to preserve an existing fixture.
- If a matching order exists, skips rebuilding the dataset and proceeds to embedded verification.
- If no matching order exists, performs scoped cleanup statements, upserts two named UAT shippers, then creates synthetic customers, eight orders, nine parcels, related delivery/COD/financial/event records, and seven invoices.
- Embedded checks require six synthetic customers, eight orders, nine parcels, seven invoices, and four COD obligations.
- A raised exception before commit should abort the fixture transaction; this is inferred from the explicit PostgreSQL transaction structure, not verified by executing it.

### Rerun safety assessment

The preservation branch is intentional: the file states that COD receipt history is immutable and a committed fixture should be retained. This avoids deleting/recreating that history on ordinary reruns.

However, the rerun decision is a coarse existence check on order notes, not a complete preflight that distinguishes a fully valid fixture from a partial or mixed dataset. A partial fixture will skip rebuilding and then fail one or more count checks. This is fail-detecting, but not self-repairing.

The cleanup path also deletes customers matching six fixed normalized phone values when no matching fixture order is found. Before any future change or execution, confirm those synthetic identifiers are reserved exclusively for this fixture and assess foreign-key dependencies. The file’s UAT naming is helpful but does not by itself prove those identifiers cannot collide with manually created staging data.

The two shippers are upserted by name and have `active` set to true. This means a fixture run can reactivate an existing row with the same name; verify the operational implications before treating these names as globally reserved.

## Migration application and failure boundaries

The workflow applies all pending staging migrations using `supabase db push` before fixture loading. The workflow does not wrap migration application, fixture loading, build, and Worker deployment in one transaction or a coordinated rollback.

Consequences:

- If migration push fails partway, inspect the migration history and actual schema before retrying; do not assume the entire push was rolled back.
- If the fixture fails, its own transaction is expected to roll back its changes, but previously applied migrations remain.
- If fixture verification, build, or Worker deployment fails after migration push, successful migration changes remain in staging.
- The workflow contains no automatic database restore or migration-down procedure. Do not improvise a reset or rollback as incident response.

The reviewed example migration `20260930130000_p15_t239_match_phone_source_fix.sql` uses `CREATE OR REPLACE FUNCTION` to replace `public.match_import_customers`. Its body updates import-row match status and the batch status. This is a function replacement, not a schema reset. This single migration is illustrative, not a complete review of all migrations in the repository.

## Findings and risk classification

| ID | Finding | Risk | Evidence / limitation |
|---|---|---|---|
| DBF-01 | Database changes are not atomic with the full staging deployment. | High | Migration push and fixture precede build/deploy; no coordinated rollback is defined in this workflow. |
| DBF-02 | Fixture reruns preserve data when any matching order exists, then rely on count checks to detect incompleteness. | Medium | The prefix existence branch skips all creation; embedded verification checks fixed totals. |
| DBF-03 | The fixture cleanup path targets customers by fixed normalized phone values if no matching fixture order exists. | Medium | Explicit delete predicate in the fixture; exclusivity and foreign-key impact are not proven by this static review. |
| DBF-04 | Existing same-name UAT shippers can be reactivated by the fixture. | Low–Medium | `ON CONFLICT (name) DO UPDATE SET active = true`. |
| DBF-05 | Workflow migration target is encoded through a staging project ID and password-based URL, while checkout follows the dispatched branch name. | High | Workflow YAML confirms target variables and `${{ github.ref_name }}`; who may dispatch it and environment approval rules remain unverified. |
| DBF-06 | Post-migration failures require a documented operator recovery path. | High | No automatic restore/rollback is present in the reviewed workflow; no live failure drill was performed. |

These are static-review findings, not claims that a staging incident has occurred.

## Required controls before implementation or operational use

1. **Target lock:** Fail closed unless the resolved database project and Worker are the intended staging targets; verify against trusted constants rather than branch-controlled files alone.
2. **Branch authorization:** Restrict staging deployment dispatch to an approved ref and verify GitHub environment reviewer/branch restrictions.
3. **Migration preflight:** Capture the migration list and schema-diff/preflight result before mutation. Stop on unexpected drift; never auto-reset to make a deployment pass.
4. **Migration observability:** Preserve sanitized before/after migration status and per-step logs, without printing credentials or connection URLs containing secrets.
5. **Fixture ownership:** Reserve the `P15-T230` prefixes, phone numbers, parcel numbers, invoice numbers, and shipper names for this fixture. Check for collisions before any destructive cleanup.
6. **Fixture completeness:** Distinguish absent, complete, and partial fixture states. Partial state should stop with a clear diagnostic and require a deliberate, reviewed recovery path rather than silent deletion or assumed repair.
7. **Failure recovery:** Document the exact response for failure during migration push, fixture load, post-load verification, build, and Worker deployment. Recovery must not default to a database reset.
8. **Postconditions:** Validate relational integrity and expected state in addition to row counts; row counts alone can pass with incorrect relationships or values.
9. **Staging-only evidence:** Test rollback and rerun behavior only in a disposable isolated test database or approved staging window, with explicit target verification. No such execution was performed for this audit item.
10. **Release gate:** Do not treat a failed Worker deployment as proof that database changes were reverted. Record database and Worker deployment states separately.

## Suggested acceptance tests for a future implementation

- First run on an empty isolated database creates exactly the documented fixture.
- Second run on a complete fixture is non-destructive and leaves immutable COD history unchanged.
- Partial fixture causes a clear failure without deleting unrelated rows.
- Deliberately conflicting customer phone or shipper name is detected and does not mutate unrelated staging data.
- An injected fixture error rolls back fixture statements while leaving previously applied migration status clearly reported.
- A build/deploy failure after database success reports the database state and does not attempt an automatic reset.
- A wrong project ID or unauthorized branch fails before any database mutation.
- Postconditions verify expected foreign-key relationships and financial totals, not only counts.

## Out of scope / not verified

- No database connection, migration push, fixture execution, reset, repair, or deployment.
- No exhaustive semantic review of all 146 migrations.
- No verification of live GitHub environment protection, secret validity, database backup restoreability, or Cloudflare token scopes.
- No claim that every migration is transactional, reversible, idempotent, or safe for large production datasets.
- No code/workflow changes, merge, or production action.

## Recommendation

Keep this audit item as **documentation/review complete; remediation pending**. Before changing the workflow, resolve DBF-01, DBF-05, and DBF-06 first. Any future implementation should be a separate, narrowly scoped change with explicit approval and staging-only validation; production database structure and data must remain untouched.
