# P14-T209

Concurrency and transactional-integrity coverage is implemented in `supabase/tests/database/121_concurrency_transactional_integrity.sql`.

The test verifies database-enforced idempotency uniqueness, conflict-safe claims, row locking for order lifecycle commands, customer-row locking and unique-race recovery, SECURITY DEFINER transactional boundaries, immutable original amounts, and absence of direct browser writes.

It is rollback-scoped and does not modify production business data. It does not claim a two-session stress test.