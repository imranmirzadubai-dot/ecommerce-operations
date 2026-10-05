# P17-T304 — Courier Active/Inactive State Management

## Scope

P17-T304 adds the trusted server-side command needed to activate or deactivate an existing courier. It reuses the existing `public.shippers.active` field and does not introduce a replacement courier table.

## Contract

Function: `public.set_courier_active(uuid, boolean, text)`

- Admin-only through `public.app_role()`.
- `security definer` with a fixed `search_path`.
- Authenticated callers receive `EXECUTE`; `anon` and `public` do not.
- Requires a courier UUID, explicit boolean target state, and idempotency key.
- Locks the target courier row before changing state.
- Preserves `id`, `courier_code`, name, contact data, and parcel relationships.
- Uses the existing command idempotency foundation.
- Records an audit event only when the active state actually changes, using `activate_courier` or `deactivate_courier`.
- Replaying the same idempotent command returns the stored result rather than applying the transition again.

## Data model boundary

The existing `public.shippers` table remains the courier master. The existing `public.shippers.active` column is the authoritative active/inactive state. `parcels.shipper_id` remains unchanged.

No direct browser `UPDATE` privilege is added to `public.shippers`.

## Verification

Database contract test: `supabase/tests/database/121_p17_t304_courier_active_state.sql`.

The test verifies the function signature, security-definer posture, execution grants, direct-write boundary, existing active field, idempotency foundation, absence of a replacement courier table, parcel relationship, and audit-log contract.

## Data safety

This task changes database behavior only through a version-controlled migration. It does not mutate production courier records during implementation or testing.

## Deferred

Courier assignment/allocation behavior remains separately scoped. This task establishes only the courier master active/inactive state transition and its security/audit boundary.
