# P14-T215 — Structured Logs

## Scope

Establish a dependency-free structured logging primitive for application diagnostics.

## Contract

- Each entry is JSON-serializable and contains `timestamp`, `level`, `message`, and `context`.
- Context supports structured fields rather than interpolated log strings.
- Authentication and secret-bearing fields are recursively redacted before emission.
- The logger uses the existing browser/runtime console transport; no external logging service or credential is introduced.
- This milestone establishes the logging contract. It does not claim centralized log retention, alerting, correlation IDs, or production observability coverage; those are separate milestones.

## Verification

Unit tests verify deterministic entry shape, JSON serialization, and recursive redaction of authentication-sensitive fields.

## Boundary

Repository/CI verification only. No production traffic, secrets, or business data are required or modified.
