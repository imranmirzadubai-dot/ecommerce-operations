# P2-T043 Completion Record

**Task:** P2-T043 — Formalize grants and privileged-function permissions  
**Phase:** 2 — Architecture Formalization & Verification  
**Status:** COMPLETE — architecture formalization and verification plan recorded  
**Completion date:** 2026-09-12

## Deliverables

- `docs/architecture/GRANTS_AND_PRIVILEGED_FUNCTIONS.md`
- `docs/test-plans/T043_GRANTS_PRIVILEGED_FUNCTION_TEST_PLAN.md`

## Verification evidence

Staging project `mijbpvgxrxjaalimyqgm` was inspected directly through PostgreSQL catalogs.

Findings:

1. Core commands `create_order`, `confirm_order`, and `cancel_order` are `SECURITY DEFINER` with `search_path=pg_catalog, public` and contain authenticated/application-role checks.
2. The idempotency helpers `claim_command_idempotency` and `complete_command_idempotency` are also `SECURITY DEFINER` with the same controlled search path and are not executable by `anon`.
3. `create_order`, `confirm_order`, and `cancel_order` are currently executable by `anon`, `authenticated`, and `service_role`. This is a contract violation because protected application commands must not be anonymously executable. It is recorded as a hardening requirement; no live staging change was made during this architecture task.
4. Table privileges show `authenticated` has SELECT on the exposed operational tables and no direct application-role write grants in the inspected grant set. `service_role` retains broad infrastructure privileges. `anon` has no listed table grants in the inspected result.
5. `financial_adjustments` is currently SELECT-granted to `authenticated`; the target RLS contract limits visibility to Admin and this remains a Phase 3 implementation requirement.

## Scope boundary

T043 formalizes the grant and privileged-function contract and records implementation gaps. It does not silently modify production or apply Phase 3 hardening.

## TCR

`ECO-TCR-P2-T043-20260912-e844fb15`
