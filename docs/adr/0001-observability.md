# ADR-0001: Observability Baseline

- Status: Accepted for MVP implementation baseline
- Date: 2026-09-11
- Scope: E-Commerce Operations MVP

## Decision

Use a structured application logging contract with request/correlation IDs, error reporting, basic performance metrics, and an operational alerting path. The concrete vendor/product selection is intentionally deferred until the production deployment/hardening stage; the application will emit vendor-neutral structured events so the transport can be selected without changing domain behavior.

## Required controls

- Every server request/command receives or propagates a correlation/request ID.
- Logs are structured and machine-readable.
- Never log passwords, authentication tokens, Supabase service-role/secret keys, or unnecessary personal data.
- State-changing commands record success/failure and correlation ID in application logs.
- Domain history remains in PostgreSQL `order_events`; security/change accountability remains in `audit_logs`.
- Errors are reported with enough context to reproduce the failure without exposing secrets or unnecessary PII.
- Basic latency/error counters are captured for production readiness.
- An operational alert path is defined before go-live.

## Consequences

This satisfies the architecture requirement without adding a monitoring vendor dependency to the MVP database or frontend. Vendor selection can occur during hardening after actual production constraints are known.
