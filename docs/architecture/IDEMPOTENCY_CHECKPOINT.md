# Idempotency Validation Checkpoint

This checkpoint records that the core command signatures now require an idempotency key and that the legacy create-order signature is removed from the database contract.

Validation must still prove the runtime retry, request-mismatch rejection, and rollback behavior before the staging command retrofit is considered complete.
