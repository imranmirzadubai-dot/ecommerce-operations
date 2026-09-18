# P11-T173 — Implement variance/Exception state

Implemented the database-enforced COD receipt variance state.

- Exact expected/received amount match produces `Received`.
- Any non-zero variance produces `Exception`.
- State is derived by a `BEFORE INSERT OR UPDATE` database trigger.
- Trigger function is `SECURITY DEFINER` with controlled `search_path` and is not directly executable by application roles.
- Added database regression coverage and dedicated CI.
- No production business data changed.
