# P14-T209 — Concurrency / Transactional Integrity Testing

## Objective

Verify the database contracts that protect state-changing operations when requests overlap or are retried concurrently.

## Evidence covered

- `command_idempotency` has a database-enforced unique key on `(actor_id, command_name, idempotency_key)`.
- Idempotency claiming uses conflict-safe insertion followed by `FOR UPDATE` locking of the existing record.
- `create_order` locks an existing customer row by normalized phone and handles a concurrent unique-insert race.
- `confirm_order` locks the target order with `FOR UPDATE` before validating and applying the lifecycle transition.
- `cancel_order` locks the target order with `FOR UPDATE` before validating and applying the lifecycle transition.
- Core browser roles have no direct INSERT/UPDATE/DELETE grants on operational tables; state changes enter through SECURITY DEFINER transactional commands.
- Original order amount is not mutated by confirm/cancel lifecycle transitions.

## Test

`supabase/tests/database/121_concurrency_transactional_integrity.sql`

The test is rollback-scoped and deterministic. It verifies the locking, uniqueness, idempotency, and transactional command contracts without creating or modifying production business data.

## Scope limitation

A single pgTAP database test session cannot itself prove timing behavior between two independent live transactions. Therefore this milestone establishes repository/local database evidence for the serialization primitives and race-handling paths; it does **not** claim a two-session stress/load test or production concurrency certification.

A later load/performance milestone can exercise simultaneous clients against a deployed environment once the required environment and test data gates permit it.

## Gate statement

P14-T209 is complete only after the migration/test chain passes CI and the PR is reviewed and merged. No production business data is required or modified by this milestone.
