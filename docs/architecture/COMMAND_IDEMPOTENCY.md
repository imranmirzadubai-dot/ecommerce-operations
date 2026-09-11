# Command Idempotency Contract

State-changing application commands must be retry-safe. Each command receives an actor-scoped idempotency key and derives a deterministic request hash from its business inputs.

The database ledger is keyed by `(actor_id, command_name, idempotency_key)`. A completed retry returns the previously stored result and performs no business writes. Reusing a key with different request data is rejected.

The ledger is internal: direct table access is revoked and only the tightly scoped SECURITY DEFINER helper functions are executable by authenticated application roles.

Current enforced commands:

- `create_order(..., p_idempotency_key text)`
- `confirm_order(p_order_id uuid, p_idempotency_key text)`
- `cancel_order(p_order_id uuid, p_idempotency_key text)`

A failed command transaction rolls back its idempotency claim, allowing a later retry to execute normally. This contract must be applied to every future state-changing command before that command is exposed to the application.
