# P2-T049 Completion Record

## Task

**P2-T049 — Select and record observability tooling ADR**

## Status

**COMPLETE — Phase 2 architecture formalization**

## Evidence commit

`da3fc4ae8385ad2510928b276464f339f85b9deb`

## TCR

`ECO-TCR-P2-T049-20260912-da3fc4ae`

## Deliverables

- `docs/architecture/OBSERVABILITY_ADR.md`
- `docs/test-plans/T049_OBSERVABILITY_ADR_TEST_PLAN.md`
- this completion record

## Decision

The MVP observability stack is:

1. Cloudflare Workers Observability for runtime logs, errors, metrics and tracing.
2. Cloudflare Notifications for the initial operational alerting path.
3. Supabase Observability/Logs for database/API/Auth platform diagnostics.
4. Application request/correlation IDs and structured privacy-safe telemetry.
5. PostgreSQL `audit_logs` and `order_events` remain authoritative business evidence.
6. Third-party observability is deferred unless a concrete operational requirement makes it necessary.

## Verification basis

Current official Cloudflare documentation confirms Workers Logs, tracing, metrics, Query Builder and OpenTelemetry export. Current Cloudflare notification documentation confirms configurable notification policies and error-rate alerting. Current Supabase documentation confirms project logs, metrics, reports and database diagnostics. These capabilities satisfy the MVP's architecture-level observability requirements without adding a mandatory third-party service.

## Scope boundary

No production changes. No staging telemetry configuration changes. No migration. No secrets added. No business data changed.

## Decision outcome

**ACCEPTED — native Cloudflare + Supabase observability with Cloudflare alerting is the MVP baseline.**

Next task: **P2-T050**.