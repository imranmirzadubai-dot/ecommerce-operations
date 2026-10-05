# P17-T305 — Courier Assignment / Allocation

## Decision

T305 confirms **parcel-level courier assignment** as the operational source of truth. The existing `public.parcels.shipper_id` relationship is retained.

No `orders.shipper_id` (or equivalent order-level courier field) is introduced. Orders can contain multiple parcels, and the parcel relationship is the existing dispatch boundary; adding a second order-level courier source would create ambiguity rather than add useful authority.

## Assignment contract

The existing `public.assign_parcel_shipper(uuid, uuid, text)` command is hardened in place rather than creating a parallel mutation API.

Rules:

- **Operations/Admin only.**
- Assignment and reassignment are allowed only while the parcel is **Prepared**.
- The target courier must exist.
- A new assignment or a change to a different courier requires the target courier to be **active**.
- Re-selecting the already assigned courier is a safe no-op and does not create a duplicate operational transition.
- Reassignment is allowed before dispatch; once the parcel leaves **Prepared**, the same command rejects the request.
- The parcel's `tracking_id` and tracking ownership are not modified by T305.
- The parcel row is locked before the assignment decision.
- The target courier row is locked before active-state validation, preventing a concurrent deactivation from racing with a successful new assignment.
- The existing command-idempotency mechanism remains the retry boundary.

## Audit / events

An unassigned parcel produces a `ShipperAssigned` order event.

A parcel changing from one courier to another produces a `ShipperReassigned` order event.

Every actual assignment/reassignment writes a privileged `audit_logs` record with the prior courier and the new courier. A same-target no-op does not generate a false change event.

The audit action is:

- `assign_parcel_shipper` for the first assignment.
- `reassign_parcel_shipper` for a change between couriers.

## Data-model boundary

T305 does not add tables, replace `public.shippers`, or add an order-level courier field.

It preserves:

- `public.shippers.id` as the courier identifier.
- `public.shippers.active` as the active-state authority.
- `public.parcels.shipper_id` as the parcel-level relationship.
- Existing RLS and SELECT-only browser access.
- Server-side mutation through a narrowly granted database command.

## Verification

Database contract test:

`supabase/tests/database/122_p17_t305_courier_assignment.sql`

CI database verification is extended to execute the T305 contract test during the normal local Supabase reset/test job.

No production data or schema is mutated by implementation or testing.

## Relationship to later P17 work

T305 establishes the assignment/reassignment command boundary. Tracking provider/URL semantics remain separate work; live courier APIs, webhook ingestion, bulk assignment and credential handling remain out of scope.
