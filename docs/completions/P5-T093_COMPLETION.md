# P5-T093 — Implement order creation

- **Task:** P5-T093 — Implement order creation
- **Phase:** 5 — Customer & Order Core
- **Milestone / Gate:** Commercial Gate
- **Status:** Complete
- **Completion date:** 2026-09-12
- **TCR:** ECO-TCR-P5-T093-20260912-2227197e

## Implementation

The order-creation flow is implemented through the canonical authenticated `create_order` command and the existing Operations workspace UI.

### Command boundary

- Canonical signature: `create_order(text,text,text,text,numeric,jsonb,text,text)`.
- Requires an authenticated user with application role `sales`, `operations`, or `admin`.
- Requires a nonblank idempotency key.
- Requires customer name, phone, non-negative AED order amount, and at least one order item.
- Resolves an existing customer by normalized phone or creates the customer transactionally.
- Creates the order in `Draft` state.
- Persists order items with validated positive whole quantities.
- Emits `OrderCreated` and writes an audit record.
- Uses the existing idempotency claim/complete boundary to make retries deterministic.
- Anonymous execution is denied; authenticated execution is granted.

### Application flow

The authenticated Operations Dashboard already exposes the Draft Order workflow: customer phone lookup, customer details, item entry, Total Order Amount (AED), notes, and submission through the canonical command client. Successful creation reports the generated order number and Draft state.

## Verification

Dedicated regression coverage was added at `supabase/tests/database/040_order_creation.sql` and wired into `.github/workflows/ci.yml`.

GitHub Actions run **423 / 34712944916** passed:

- lint
- typecheck
- unit tests
- build
- fresh local Supabase startup
- `supabase db reset`
- rebuild verification
- customer-resolution regression tests
- order-creation regression tests

The broader legacy pgTAP suite remains outside this task's acceptance scope and is not claimed green.

## Scope / security boundary

No new business permission was invented. Order creation remains available only to the approved authenticated application roles, uses the existing transactional command boundary, and preserves the browser's lack of direct table-write privileges. No production environment was changed.

## Task Completion Reference

`ECO-TCR-P5-T093-20260912-2227197e`
