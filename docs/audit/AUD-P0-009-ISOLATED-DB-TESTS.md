# AUD-P0-009 — Isolated Supabase and Database-Test Baseline

**Recorded:** 2026-10-20  
**Status:** Isolated local Supabase confirmed in CI; configured database test step passed.

## Environment and isolation evidence

- Repository: https://github.com/imranmirzadubai-dot/ecommerce-operations
- Target source baseline: `main` at `40f03c22332a2b8653c7e78b609b4d891c33ce18`
- CI run: [CI run #39319087121](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/39319087121)
- Job: `database`, on an ephemeral GitHub Actions `ubuntu-latest` runner.
- Supabase CLI setup: `supabase/setup-cli@v1`, pinned to version `2.105.0`.
- Local database startup: `supabase db start` — completed successfully.
- Local reset and database tests: completed successfully according to the job step status.
- The workflow connects to PostgreSQL via `127.0.0.1:54322` with the local Supabase default test credentials and runs `pg_prove` against the explicitly listed files under `supabase/tests/database/`.

## Test coverage executed by the configured CI command

The CI workflow's database step resets the runner-local Supabase database, installs the pgTAP parser dependency, enables the `pgtap` extension, and runs the configured SQL test list. That list includes database rebuild smoke checks, customer/order lifecycle and validation, parcel allocation and dispatch, delivery outcomes/reconciliation, courier model and assignment tests, import regression, admin invite provisioning, security-definer role guards, and matched-customer integrity.

The workflow includes `supabase/tests/database/172_import_matched_customer_integrity.sql`. The exact test assertion count and raw pgTAP output are not available through the connected GitHub job-step summary, so no assertion count is claimed here.

## Safety conclusion

The reviewed CI workflow starts Supabase within the ephemeral runner and addresses PostgreSQL at loopback `127.0.0.1:54322`; it does not use a hosted production database URL for these test commands. The reset therefore applies to the runner-local CI database only.

No production database, schema, or data was accessed or changed by this audit task. No local machine availability is asserted; this evidence confirms the isolated CI environment, not a local Supabase installation.

## Result

The existing isolated CI database workflow is available and its database job completed successfully for the recorded run. Preserve the workflow's local-only connection assumptions in future test changes.
