# P17-T295 — Extend Shipper/Courier Data Model

The existing `public.shippers` table is retained as the courier master. `public.parcels.shipper_id` remains the parcel-level relationship.

## Additive fields

- `courier_code` — stable human-friendly identifier (`CRR-000001` format), unique and required.
- `contact_name`
- `contact_phone`
- `contact_email`
- `address`
- `notes`

The existing UUID primary key remains the internal immutable identifier.

## Deliberately deferred

- courier creation/edit commands — T296/T300
- duplicate/business-rule enforcement — T302
- operational configuration — T304
- order-level courier relationship — T305
- assignment workflow/authorization — T306/T307
- tracking ownership/URL/API credentials — T309–T314

## Security

- Existing RLS on `public.shippers` remains unchanged.
- Authenticated users retain SELECT-only access.
- No browser write grant is introduced.
- State-changing operations remain behind trusted server-side commands.
- No service-role credentials are exposed.

## Compatibility

The migration is additive and safe for existing rows: pre-existing shippers receive generated courier codes before the new NOT NULL/format contract is enforced.
