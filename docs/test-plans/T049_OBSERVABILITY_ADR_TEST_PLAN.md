# T049 Observability ADR Test Plan

## Purpose

Verify that the selected observability architecture is explicit, privacy-safe, non-authoritative for business correctness, and sufficient to support Phase 3 implementation.

## Acceptance matrix

| ID | Scenario | Expected |
|---|---|---|
| T049-01 | Worker invocation produces operational telemetry | Invocation/log evidence is available through Cloudflare observability |
| T049-02 | Worker runtime exception occurs | Error is visible without exposing secrets |
| T049-03 | Successful request | Structured request telemetry includes safe correlation ID and outcome |
| T049-04 | Request without correlation ID | Application generates one |
| T049-05 | Request with valid safe correlation ID | ID is validated and propagated |
| T049-06 | Malformed/oversized correlation ID | Rejected or replaced safely |
| T049-07 | Correlation ID contains customer/secret data | Not accepted as an unrestricted diagnostic identifier |
| T049-08 | Command failure | Stable error class/code and correlation ID are available |
| T049-09 | Password/token/service-role key reaches error path | Secret is absent/redacted from telemetry |
| T049-10 | Business command request body is logged | Full payload is not emitted |
| T049-11 | Supabase API/Postgres/Auth failure | Supabase Logs provide platform-side diagnostic evidence |
| T049-12 | Worker performance degradation | Worker metrics expose request/error/performance signal |
| T049-13 | Request-flow investigation | Cloudflare tracing can correlate supported request/subrequest activity |
| T049-14 | Sustained 5xx condition | Configured Cloudflare alert path can notify operations |
| T049-15 | Telemetry destination unavailable | Business transaction is not made dependent on telemetry delivery |
| T049-16 | Audit event emitted | `audit_logs` remains authoritative and is not replaced by telemetry |
| T049-17 | Domain event emitted | `order_events` remains authoritative business history |
| T049-18 | Sampling is enabled | Required incident signal remains available according to configured policy |
| T049-19 | Production telemetry review | Retention/privacy configuration does not expose unnecessary PII |
| T049-20 | Third-party telemetry vendor absent | MVP remains operable using native Cloudflare/Supabase tooling |

## Phase 3 implementation checks

- Worker observability configuration.
- Correlation-ID middleware.
- Structured logging helper.
- Secret/PII redaction tests.
- Error classification.
- Metrics and trace configuration.
- Cloudflare notification policy tests.
- Supabase log access and diagnosis procedure.
- Runbook links from operational alerts.

## Exit criteria

The observability vendor/tooling decision is recorded in an ADR, acceptance scenarios are explicit, current platform capabilities have been verified against official documentation, and no production/staging telemetry configuration is changed merely to close the architecture task.