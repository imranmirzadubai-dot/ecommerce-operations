# P14-T209 Scope

This milestone verifies concurrency and transactional-integrity primitives in the repository database contract: idempotency uniqueness and locking, order-row locking for lifecycle transitions, customer-row locking and unique-race recovery, SECURITY DEFINER transactional command boundaries, and absence of direct browser writes. The pgTAP test is rollback-scoped and does not modify production business data.

A single pgTAP session does not constitute a two-session concurrency stress test; this milestone records that limitation explicitly.