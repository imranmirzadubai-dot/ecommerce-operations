# P14-T218 — Performance Metrics

## Scope

Establish a dependency-free application performance-metrics primitive for measuring operation duration and recording metric samples.

## Implemented

- Metric samples contain name, non-negative numeric value, unit, timestamp and bounded scalar tags.
- Synchronous and asynchronous duration helpers use a monotonic timing source by default.
- Failed operations preserve the error path while characterizing elapsed time with an `outcome=error` tag.
- Deterministic unit tests cover validation, timestamps, synchronous duration and asynchronous duration.

## Boundary

This milestone provides application instrumentation primitives. It does not claim a centralized metrics backend, long-term metric storage, dashboards, alerting, distributed tracing, or production performance certification.
