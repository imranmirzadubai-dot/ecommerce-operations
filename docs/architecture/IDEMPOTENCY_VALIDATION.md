# Idempotency Validation

Core state-changing command signatures require an actor-scoped idempotency key.

Runtime validation remains required for retry replay, request-mismatch rejection, and rollback behavior before staging adoption.
