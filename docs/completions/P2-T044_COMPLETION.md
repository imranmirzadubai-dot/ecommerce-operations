# P2-T044 Completion Record

**Task:** P2-T044 — Formalize command/API schemas  
**Phase:** 2 — Architecture Formalization & Verification  
**Gate:** Architecture Gate  
**Status:** COMPLETE — command/API schema contract formalized  
**Completion date:** 2026-09-12

## Deliverables

- `docs/architecture/COMMAND_API_SCHEMAS.md`
- `docs/test-plans/T044_COMMAND_API_SCHEMA_TEST_PLAN.md`

## Repository evidence

The command schema registry was derived from the version-controlled migrations on the T044 branch, including:

- `resolve_customer_by_phone`
- `create_order`
- `confirm_order`
- `cancel_order`
- `cancel_parcel`
- internal `claim_command_idempotency`
- internal `complete_command_idempotency`

The idempotency retrofit migration explicitly replaces the pre-idempotency signatures for the three core order commands, making the idempotency key part of their canonical state-changing interface.

## Staging verification

Staging project `mijbpvgxrxjaalimyqgm` was inspected through PostgreSQL catalogs on 2026-09-12. The currently visible command signatures include:

- `create_order(p_customer_name text, p_phone text, p_address text, p_city text, p_original_amount numeric, p_items jsonb, p_notes text, p_idempotency_key text)` → order/customer result table;
- `confirm_order(p_order_id uuid, p_idempotency_key text)` → order result table;
- `cancel_order(p_order_id uuid, p_idempotency_key text)` → order result table;
- `claim_command_idempotency(...)` → `is_new`, `status`, `result`;
- `complete_command_idempotency(...)` → `void`.

These observed functions are `SECURITY DEFINER` with `search_path=pg_catalog, public`.

The staging catalog query did not currently return `resolve_customer_by_phone` or `cancel_parcel`, even though both are present in the version-controlled migration contract. This is an implementation/environment drift item and is not being silently treated as a Phase 3 completion claim.

## Scope boundary

T044 formalizes the command/API schemas and verification requirements. It does not claim that all future Phase 3 command implementations exist, nor does it silently modify staging or production to reconcile drift.

## TCR

`ECO-TCR-P2-T044-20260912-9119ec6a`
