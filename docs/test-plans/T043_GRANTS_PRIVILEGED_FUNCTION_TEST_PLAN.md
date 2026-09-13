# T043 Grants and Privileged-Function Verification Test Plan

## Purpose

Verify the Phase 2 grant and privileged-function permission contract without relying on UI behavior.

## Catalog-level tests

- **T043-01** — Enumerate privileges on every public application table for `anon`, `authenticated`, and `service_role`.
- **T043-02** — Assert `anon` has no application-table access.
- **T043-03** — Assert normal application transport access has no direct `INSERT`/`UPDATE`/`DELETE` on command-owned domain tables.
- **T043-04** — Enumerate all public functions and their `EXECUTE` privileges.
- **T043-05** — Assert protected commands are not executable by `anon` or `PUBLIC`.
- **T043-06** — Assert each client-callable command has an explicit authenticated `EXECUTE` grant.
- **T043-07** — Enumerate `SECURITY DEFINER` functions and verify controlled `search_path` configuration.
- **T043-08** — Verify security-definer references are schema-qualified and helper exposure is minimized.
- **T043-09** — Verify `service_role` is the only infrastructure role with broad backend privileges required by deployment/runtime.

## Behavioral authorization tests

- **T043-10** — Unauthenticated caller cannot execute protected commands.
- **T043-11** — Sales cannot execute Operations-only commands.
- **T043-12** — Sales cannot execute Admin-only commands.
- **T043-13** — Operations cannot execute Admin-only commands.
- **T043-14** — Admin can execute Admin-authorized commands when business invariants pass.
- **T043-15** — Eligible cancellation succeeds for Sales, Operations, and Admin when lifecycle/financial preconditions pass.
- **T043-16** — Ineligible cancellation is rejected for every application role.
- **T043-17** — Direct table mutation cannot bypass command-owned lifecycle state.
- **T043-18** — Direct mutation of immutable identifiers/history is rejected.
- **T043-19** — A lower-level helper cannot be used to bypass command authorization or invariants.

## Role and token tests

- **T043-20** — User with no active application role fails closed.
- **T043-21** — Role changes do not create an authorization bypass through stale browser claims/tokens.
- **T043-22** — Application-role validation is performed from the authoritative protected role source.

## Evidence requirements

Record SQL/catalog output for grant tests, function security-definer configuration, and representative positive/negative command calls. Any mismatch is recorded as a hardening requirement and is not silently corrected during architecture verification.

## Completion rule

T043 is complete when the grant/privileged-function architecture document and this verification plan are committed on the T043 branch, with known implementation gaps explicitly recorded and no unsupported production-state claims.
