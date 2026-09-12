# ADR-OBS-001 — MVP Observability

**Status:** Accepted for Phase 2 Architecture Freeze
**Date:** 2026-09-11
**Scope:** E-Commerce Operations MVP

## Decision

Use the native observability capabilities already provided by Cloudflare Workers and Supabase Cloud as the MVP observability baseline. Do not introduce a separate paid third-party observability platform during the three-day MVP unless a concrete operational requirement cannot be met by the native stack.

The application will add structured, privacy-safe application events at the Worker boundary and will use a request/correlation ID to connect a browser request, Worker command/API execution, and downstream Supabase operation where the platform exposes the relevant telemetry.

## Why

The v4.0 architecture is a single React + TypeScript + Vite application deployed as a Cloudflare Worker, with Supabase Auth and PostgreSQL as the authoritative backend. The architecture requires structured application logs, error reporting, request/correlation IDs, basic performance metrics and an operational alerting path before production.

Cloudflare Workers currently provides Workers Logs, request/error metrics, tracing, Query Builder and OpenTelemetry export. Newly created Workers have observability enabled by default, and the repository's `wrangler.jsonc` already enables observability. Cloudflare tracing can automatically capture Worker handler and fetch/subrequest telemetry without an application tracing SDK.

Supabase Cloud provides project Logs for API Gateway, Postgres, PostgREST, Auth, Storage and other services, plus reports and metrics. This is sufficient for MVP diagnosis of database/API/authentication failures without adding another telemetry vendor.

## Options considered

### A — Cloudflare + Supabase native observability
**Selected.** Lowest complexity, already aligned with the deployment architecture, and sufficient for MVP operational diagnosis.

### B — Third-party platform such as Sentry/Grafana Cloud/Axiom
**Deferred.** Potentially useful for longer-term centralized error analysis, alerting and cross-service telemetry, but adds account, secret, cost and deployment complexity that is not required to prove the MVP workflow.

### C — Custom logging/metrics service
**Rejected.** Unnecessary infrastructure and an additional failure/maintenance surface.

## Required telemetry

### Request correlation
Every server-side request should have a correlation/request identifier. If an incoming request already supplies a safe correlation ID, validate and propagate it; otherwise generate one. Never use customer phone numbers, addresses, order contents, access tokens or other PII as correlation IDs.

### Structured application events
Worker logs should record only operationally useful fields, such as:

- event name
- timestamp
- correlation/request ID
- HTTP method/path category
- command name where applicable
- authenticated actor UUID where operationally justified
- result class (`success`, `client_error`, `server_error`)
- HTTP status
- duration in milliseconds
- deployment/version identifier where available
- downstream dependency class (`supabase_rest`, `supabase_auth`) where applicable
- error code/class, without secrets or unnecessary personal data

Business audit history remains in PostgreSQL `audit_logs` and `order_events`. Observability logs are diagnostic telemetry and are **not** the authoritative business history.

## Sensitive-data policy

Never log:

- passwords
- access tokens or refresh tokens
- service-role/secret keys
- publishable keys unless required for debugging configuration
- full request bodies for business commands
- customer phone numbers
- customer addresses
- payment credentials
- complete order contents
- other unnecessary personal data

Errors should use stable application/error codes and sanitized messages rather than dumping raw payloads.

## Metrics

MVP health metrics:

1. request count
2. 4xx rate
3. 5xx rate
4. Worker exceptions
5. command/API latency
6. Supabase request failures
7. authentication failures
8. database transaction failures
9. idempotency conflicts/replays
10. bulk-operation failure counts where implemented

Cloudflare Workers metrics are the primary runtime/performance source. Supabase Logs/Reports and database inspection are the primary backend/database diagnostic sources.

## Alerting

MVP alerting should focus on conditions that threaten operational correctness or availability:

- sustained Worker 5xx errors
- repeated authentication failures indicative of an operational/security problem
- repeated database/API failures
- abnormal command failure rates
- production deployment errors
- backup/export failures once the backup job exists

Exact thresholds should be established during production hardening from observed baseline traffic rather than invented during the architecture freeze.

## Tracing

Cloudflare Worker tracing is enabled when needed for request-flow diagnosis. Use the native automatic instrumentation first. Do not add an application tracing SDK merely to duplicate platform telemetry.

## Environment policy

- **Local:** developer console/logging and local Supabase diagnostics.
- **Preview:** Cloudflare observability enabled; test data only.
- **Staging:** Cloudflare and Supabase native logs/metrics used for integration/UAT diagnosis.
- **Production:** same baseline, with defined alert thresholds and retention/RPO/RTO procedures added before Go-Live.

Production observability must not become a path for exposing production secrets or unnecessary customer data.

## Failure behavior

Observability must never determine business correctness. If telemetry delivery, log processing or an external monitoring destination fails, the transactional command must still succeed or fail according to its normal application/database rules.

Business state is authoritative in PostgreSQL. Audit/event records are authoritative for business history. Observability is diagnostic only.

## Acceptance criteria

- `wrangler.jsonc` has Worker observability enabled.
- Worker errors and invocation logs are available through Cloudflare observability.
- Supabase staging provides accessible project logs for API/Auth/Postgres diagnosis.
- Server-side requests have a correlation/request identifier.
- Logs are structured and sanitized according to the sensitive-data policy.
- Critical command failures expose a stable error classification without exposing secrets or unnecessary PII.
- Observability failures cannot partially commit or alter business state.
- Production alert thresholds and retention/RPO/RTO details are finalized before the Production Readiness Gate.

## Rollback / change policy

Changing the observability vendor or adding external telemetry is an architecture change and requires a new ADR. Business commands, database authorization and audit semantics must not be changed solely to accommodate a telemetry vendor.

## References

- Cloudflare Workers Observability: https://developers.cloudflare.com/workers/observability/
- Cloudflare Workers Logs: https://developers.cloudflare.com/workers/observability/logs/workers-logs/
- Cloudflare Workers Traces: https://developers.cloudflare.com/workers/observability/traces/
- Supabase Observability: https://supabase.com/docs/guides/observability
- Supabase Logs: https://supabase.com/docs/guides/observability/logs
