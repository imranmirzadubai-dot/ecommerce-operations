# P14-T217 — Request / Correlation IDs

## Scope

Establish a deterministic request/correlation identifier primitive for application observability and authenticated reporting requests.

## Implemented

- `createCorrelationId()` accepts only bounded header-safe identifiers and generates a UUID when no valid identifier is supplied.
- `createCorrelationContext()` provides a reusable `{ correlationId }` context for related log/error events.
- `correlationHeaders()` emits the `X-Correlation-ID` request header.
- Report Workspace requests generate one correlation ID per report request and send it with the authenticated Supabase REST request.
- Report request failures log the same correlation ID through the structured logger.
- Error reporting preserves a supplied correlation ID or generates one when an error is reported without one.
- Unit tests cover validation, generation, context/header consistency, and header-safety bounds.

## Security boundary

Correlation IDs are identifiers only. They do not contain authentication credentials, customer data, or secrets. Existing structured-log recursive redaction remains in force.

## Verification boundary

This milestone verifies the application-level generation, propagation, and logging contract. It does not claim that Supabase or Cloudflare persists, indexes, or exposes the header downstream, nor does it establish centralized log storage, tracing, alerting, or production observability.
