# P14-T213 — Execution Note

The milestone uses rollback-scoped synthetic data and PostgreSQL `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` to inspect representative access paths. The test validates the locked index inventory and records analyzed execution-time checks. It deliberately avoids altering production schema or business data.
