# Migration Lineage Reconciliation — 2026-09-16

## Status
**Reconciliation finding complete; deployment remediation intentionally not applied.**

## Verified state

- Production/main repository head at audit time: `213b088255dd3feb3632ae9c810af334ec2db8fe`.
- Staging Supabase project: `mijbpvgxrxjaalimyqgm`.
- Staging migration history contains **33 applied migration IDs**.
- The first recorded staging migration is `20260910212711`; the last is `20260912040049`.
- Current repository migration filenames include `20260910212711_database_foundation_v4.sql` and later migrations such as `20260911120000_transactional_commands_core.sql`, `20260911130000_command_idempotency.sql`, `20260912090000_profiles_role_model.sql`, and subsequent migrations through September 2026.
- Searches of the current repository for representative staging IDs including `20260910222428` and `20260911003036` do not locate corresponding migration files.

## Finding

The staging migration ledger and the current repository migration directory are **not a one-to-one lineage**. The safe conclusion is migration-lineage divergence, not that a fixed number of current repository migrations have been applied to staging.

The staging database is a live, non-empty environment with application schema and RLS policies. Therefore, blindly running the current repository migration directory against staging or production is not an acceptable reconciliation method: it could attempt to recreate, alter, or conflict with objects whose historical creation path is not represented by the current filenames.

## Safe target state

Establish a canonical migration baseline before any production migration/deployment:

1. Preserve the current staging database and its existing migration ledger as evidence.
2. Recover the historical SQL corresponding to all 33 staging migration IDs from repository history/backups or the Supabase migration source that originally produced the staging database.
3. Build an explicit mapping from each historical staging ID to its source SQL and the current schema objects it introduced/changed.
4. Compare that historical lineage with the current repository migration set and identify replaced, superseded, squashed, renamed, or missing migrations.
5. Choose one canonical forward path: either restore the missing historical migration chain into version control, or create a documented baseline representing the already-deployed staging schema followed only by new forward migrations.
6. Rebuild a disposable database from the canonical repository path and run the full database test suite before touching production.
7. Only after that verification, establish and execute the production migration plan.

## Explicit non-actions

- No staging reset was performed.
- No production DDL was executed.
- No attempt was made to mark unmatched historical migration IDs as applied.
- No current migration was renamed merely to match a historical ID.
- No destructive schema reconciliation was performed.

## Evidence limitation

The currently accessible GitHub repository does not contain the missing historical migration files under their staging IDs, and the available database connector did not provide a safe successful read of the staging migration catalog during this reconciliation pass. The 33-ID staging ledger and schema/RLS findings therefore remain based on the previously captured audit evidence. The next required evidence source is the original historical migration SQL or an equivalent schema/migration export from the staging environment.

## Decision gate

**Do not deploy current repository migrations to production yet.** The migration lineage must first be made reproducible and independently verifiable.