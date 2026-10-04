# P17-T300 — Courier Edit

Adds the trusted state-changing command for editing courier master data on the existing `public.shippers` table.

## Contract

- `public.update_courier(...)` is Admin-only and requires an authenticated active Admin through the existing `public.app_role()` boundary.
- The existing courier UUID (`shippers.id`) is the immutable target identifier.
- `courier_code` is immutable and is never accepted as an edit input.
- `active` is not changed by T300; operational configuration remains T304.
- Editable master-data fields are `name`, `contact_name`, `contact_phone`, `contact_email`, `address`, and `notes`.
- `name` is required, trimmed, and bounded to 200 characters. Existing database uniqueness remains authoritative; broader duplicate/business rules remain T302.
- Contact fields are optional. Blank values normalize to NULL and contact email is lower-cased server-side.
- Contact field limits match T296: contact name 200, phone 50, email 320, address 500, notes 2000 characters.
- The command uses the existing command-idempotency foundation. Reusing an idempotency key with a different request hash fails closed; a completed retry returns the original result.
- The operation records a privileged `audit_logs` event containing before/after courier master data.
- No direct browser write privilege is added to `public.shippers`.
- No replacement courier table is introduced and the existing `parcels.shipper_id` relationship is preserved.

## Deliberately deferred

- Duplicate/business-rule enforcement beyond the existing name uniqueness constraint — T302.
- Operational configuration and active-state management — T304.
- Order-level courier relationship — T305.
- Assignment workflow/authorization — T306/T307.
- Tracking ownership/URL/API credentials — T309–T314.

## Safety

- No production data mutation is part of T300.
- The migration only creates/replaces the trusted command function and grants execute access to the authenticated role; the underlying table remains SELECT-only to the browser role.
