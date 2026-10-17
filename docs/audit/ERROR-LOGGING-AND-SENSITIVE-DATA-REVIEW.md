# Error Handling, Logging, and Sensitive-Data Exposure Review

**Audit item:** AUD-P1-011  
**Scope:** Read-only static review of browser error reporting, log sanitization, React error boundary, and selected Worker logging patterns on `main`.

**Reviewed sources:** `src/lib/errorReporting.ts`, `src/lib/logger.ts`, `src/components/ErrorBoundary.tsx`, `src/main.tsx`, and selected authentication/RPC/read handlers in `worker/index.ts`.

**Execution boundary:** No application was run, no requests were sent, no logs or secrets were accessed, no database was accessed, and no code or configuration was changed.

## Executive summary

The application has centralized browser error reporting, structured JSON logs, correlation context, and a React error boundary. The logger redacts several common token/password field names. The Worker generally logs request IDs, route/command names, status, duration, and outcome rather than request bodies.

The principal risk is that redaction is key-based and incomplete as a general sensitive-data control. Browser error reporting records exception messages and stack traces; arbitrary error strings and nested context values may contain sensitive data even when their property names are not on the redaction list. This review did not inspect production log destinations, retention, access control, or actual log samples.

## Observed controls

- `src/lib/errorReporting.ts` captures global `error` and `unhandledrejection` events and React error-boundary failures.
- The reporting context includes a correlation context and captures error name, message, and stack for `Error` objects.
- `src/lib/logger.ts` emits structured JSON with timestamp, level, message, and sanitized context.
- The logger redacts exact keys including `access_token`, `accessToken`, `refresh_token`, `refreshToken`, `authorization`, `password`, `token`, `service_role`, and `serviceRole`.
- The React error boundary displays a generic failure message and a reload action instead of rendering the exception details to the user.
- Reviewed Worker handlers log operational metadata such as request ID, command/action, status, result, duration, and dependency. The inspected RPC handler forwards the upstream response body but does not log the response body in its command log.

## Findings

| ID | Finding | Risk | Evidence / limitation |
|---|---|---|---|
| LOG-01 | Exception messages and stack traces are logged without content-level sanitization. | High until validated | `reportError` records `error.message`, `error.stack`, or `String(error)`. These values may embed URLs, identifiers, request fragments, or other sensitive data. No actual log samples were reviewed. |
| LOG-02 | Redaction depends on exact property names and does not sanitize arbitrary string values. | High until validated | The logger redacts selected keys recursively, but a secret placed in a differently named field or inside a message/string is not removed by this logic. |
| LOG-03 | Sensitive-data policy and production log governance are unverified. | Medium | Source review does not establish where logs are shipped, who can access them, retention duration, deletion controls, or whether browser console logs are collected centrally. |
| LOG-04 | Error-boundary text says the error was “recorded locally,” but the implementation sends it through the shared logger to console output. | Low / clarity | The wording may imply a durable local record; the reviewed component does not itself persist a log. Actual downstream collection is unknown. |
| LOG-05 | Worker authentication logs include actor identifiers for admin-invitation events. | Medium / verify minimization | Selected Worker code logs actor and invited-user IDs for operational outcomes. These may be justified for auditability, but retention and access policy should be documented. |
| LOG-06 | Safe handling of upstream error payloads should be tested end-to-end. | Medium | The RPC handler returns upstream response bodies to the caller and selected read handlers return upstream response bodies. Whether upstream error payloads can contain internal details depends on upstream behavior and client presentation; no requests were sent. |

## Recommendations

1. Prefer allowlisted, structured error fields over raw exception messages and stacks in production. Preserve a correlation ID for authorized diagnostic lookup.
2. Redact or omit query strings, request bodies, authorization material, refresh tokens, passwords, customer contact details, and financial payloads before emitting any logs.
3. Extend tests for nested values, arrays, mixed-case key variants, alternate token field names, secrets embedded in error messages, and non-Error rejection values. Prefer a documented allowlist or centralized sensitive-value scrubber over an expanding denylist alone.
4. Separate development diagnostics from production telemetry; ensure production errors do not expose stack traces or sensitive payloads to ordinary users.
5. Verify the actual log destination, access permissions, retention, deletion, and incident access process with the platform configuration. No such settings were examined in this audit item.
6. Review whether actor/user identifiers in Worker logs are necessary, and set documented retention and access controls.
7. Add tests that upstream error responses are normalized before reaching browser-facing clients and that UI error messages remain generic.
8. Correct the error-boundary wording or document the actual log collection behavior so operators know whether errors are merely written to console or retained centrally.

## Proposed acceptance tests

- Inject a synthetic token into each redacted key and verify it is never emitted.
- Inject synthetic secrets into differently named fields, error messages, stack traces, arrays, and nested objects; verify the chosen production sanitization policy removes or blocks them.
- Verify passwords, authorization headers, refresh tokens, customer phone/address, and financial values are not recorded in routine logs.
- Verify browser users receive generic error messages while authorized operators can correlate failures without exposing raw secrets.
- Verify Worker upstream 4xx/5xx responses cannot leak credentials, SQL internals, stack traces, or sensitive payloads.
- Verify production log access and retention configuration through read-only platform settings review.

No tests were run for this item.

## Limitations and safety

- Static review only; no runtime tests, log inspection, platform configuration inspection, or user-data access.
- No secrets were read or included in this document.
- No source code, logging behavior, database, workflow, or deployment was changed.
- No production or staging action was performed.

## Recommendation

Record this targeted static review as complete with runtime and log-governance verification pending. Prioritize LOG-01 and LOG-02 before claiming sensitive-data redaction is comprehensive. Any remediation should be a separate change with synthetic-data tests and no production database changes.
