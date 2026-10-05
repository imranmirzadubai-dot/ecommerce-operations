# P17-T302 — Courier Duplicate / Business Rules

Adds the database-level business rule that prevents duplicate courier identities caused by case or surrounding whitespace differences in the courier name.

## Contract

- The existing `public.shippers` table remains the courier master.
- Courier names are compared using `lower(btrim(name))` for uniqueness.
- `Acme Logistics`, ` acme logistics `, and `ACME LOGISTICS` therefore represent the same courier identity and cannot coexist.
- The rule is enforced by a unique expression index so concurrent trusted commands cannot bypass the duplicate check.
- Existing display names are not rewritten; the rule affects identity comparison only.
- Existing `courier_code` uniqueness and format remain unchanged.
- Existing `parcels.shipper_id` relationship remains unchanged.
- No direct browser write privilege is added.

## Deliberately deferred

- Operational configuration and active-state management — T304.
- Order-level courier relationship — T305.
- Assignment workflow/authorization — T306/T307.
- Tracking ownership/URL/API credentials — T309–T314.

## Safety

- No production data mutation is part of T302.
- The migration only adds a unique database index and tests its contract.
