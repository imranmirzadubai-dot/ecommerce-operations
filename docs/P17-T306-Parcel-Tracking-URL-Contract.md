# P17-T306 — Parcel Tracking URL Contract

## Decision

Use a generic third-party tracking lookup link for any non-empty parcel tracking ID. The UI does not need to know or verify the courier provider before opening the lookup.

The implementation uses the fixed HTTPS endpoint `https://www.17track.net/en` and passes the existing tracking ID in the `nums` query parameter. The destination is a general tracking lookup service, not a claim that the parcel's courier or live delivery status has been verified.

## Existing data contract

- `public.parcels.shipper_id` remains the authoritative parcel-to-courier relationship.
- `public.parcels.tracking_id` remains the sole tracking identifier.
- Individual and bulk dispatch continue using the existing tracking ID and commands.
- No tracking URL is stored in the database and no courier-specific URL templates are added.
- No new tables, columns, migrations, or order-level courier fields are introduced.

## UI and URL safety

- Show a **Track shipment** link only when the tracking ID is non-empty after trimming.
- Build the URL from a fixed HTTPS host; never accept a destination URL from user input.
- Encode the tracking ID through `URLSearchParams`; do not concatenate raw tracking input into a URL.
- Open the external page in a new tab with `rel="noopener noreferrer"`.
- The external tracking service receives the tracking ID. The link may not resolve every carrier or every tracking number; the tracking ID remains visible in the app if the external service cannot identify it.
- No courier API credentials, access tokens, or customer details are included in the link.

## Verification

Unit tests cover empty input, whitespace trimming, URL encoding, and the fixed HTTPS host. UI surfaces expose the link in parcel allocation, individual dispatch, and bulk dispatch results/queue.

## Scope and safety

This is a UI/helper-only change. It does not alter dispatch state transitions, assignment rules, audit events, idempotency, RLS, database schema, production data, or deployment configuration. Live courier APIs, webhooks, polling, and status synchronization remain out of scope.
