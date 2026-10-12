# P17-T306 — Parcel Tracking URL Contract

## Status

Design decision only. This document does not implement tracking URLs, add database fields, change courier records, or call courier APIs.

## Current implementation

- `public.parcels.shipper_id` is the authoritative parcel-to-courier relationship.
- `public.parcels.tracking_id` is entered and stored by the existing dispatch workflow.
- Dispatch requires a parcel to have an assigned active courier and a tracking ID.
- Bulk dispatch reuses the existing tracking ID; it does not create a second tracking value.
- The current courier master (`public.shippers`) has identity, contact, address, notes, and active-state fields, but no defined tracking URL template/provider contract.
- No current `tracking_url` field or agreed provider-specific URL format was found in the inspected application code.

## Decision

Do not construct tracking URLs from courier names, tracking IDs, or guessed URL patterns. A link that looks plausible but points to the wrong provider can expose unrelated tracking data or mislead operations.

Keep the current tracking ID as the only tracking value until a courier's official tracking URL format is explicitly verified and a product decision defines how it is configured.

## Recommended implementation sequence

1. **Confirm provider requirements**: identify the couriers actually used and verify each official tracking page and supported tracking-ID format.
2. **Choose the smallest data contract**: if a fixed official URL template is sufficient, decide whether it belongs to the existing courier record or a separately governed configuration. Do not create a new table or column until this decision is reviewed against the live schema and migration history.
3. **Define URL safety rules**:
   - HTTPS only.
   - Allow only explicitly approved hostnames/templates; never accept arbitrary URLs from parcel or customer input.
   - Encode the tracking ID as a URL component.
   - Do not include access tokens, customer details, or other secrets in the URL.
   - If the provider cannot be verified, show the tracking ID as plain text rather than a link.
4. **Expose the link in the parcel UI** only when a verified provider template and a non-empty tracking ID are both present. Open external tracking pages safely in a new tab with appropriate opener protections.
5. **Test edge cases**: missing courier, inactive courier, missing tracking ID, unusual tracking characters, unknown provider, and a provider template that fails validation.
6. **Deploy separately**: any schema migration, production configuration, or production deployment requires its own review and explicit approval.

## Out of scope

- Live courier API integrations, polling, webhooks, and status synchronization.
- Replacing or duplicating `public.parcels.shipper_id` or `public.parcels.tracking_id`.
- Adding an order-level courier field.
- Editing production data or applying a production migration.

## Acceptance criteria for a later implementation

- The link is generated only from a verified, approved courier configuration.
- The raw tracking ID remains the source value; no competing tracking identifier is introduced.
- Unknown or incomplete configuration safely falls back to displaying the tracking ID without a link.
- Existing dispatch, bulk dispatch, parcel state transitions, audit events, and command idempotency remain unchanged.
- Automated tests cover URL validation and fallback behavior.
