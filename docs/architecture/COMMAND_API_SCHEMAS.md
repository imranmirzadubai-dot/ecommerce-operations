# Command/API Schemas — T044

## 1. Purpose

This document formalizes the command/API contract for the E-Commerce Operations MVP. It defines the public command shapes, input validation, result schemas, error categories, authorization expectations, idempotency behavior, and audit requirements.

The command boundary is authoritative for state-changing operations. UI forms and transport handlers must not invent alternate business rules.

## 2. API principles

1. Commands are explicit operations, not generic table CRUD.
2. Inputs are validated at the command boundary.
3. State-changing commands require an idempotency key.
4. A retry with the same actor, command, key, and request payload returns the original completed result.
5. Reuse of an idempotency key with a different request is rejected.
6. Commands execute atomically: validate → mutate → audit/event → complete idempotency → return.
7. Authorization is evaluated from the authenticated identity and authoritative application role.
8. Generated identifiers are returned by the database; callers do not supply them.
9. Historical records are not overwritten to represent corrections.
10. Internal helper functions are not part of the browser-facing API contract.

## 3. Transport contract

The MVP uses the single React + TypeScript + Vite application and one Cloudflare Worker per environment. The Worker/server layer is the application API boundary; Supabase PostgreSQL functions are the transactional command boundary where database atomicity is required.

Authentication is required for application commands. `anon` is not a valid command caller. `service_role` is backend-only infrastructure access and is not a browser API credential.

## 4. Command schema registry

| Command | Purpose | Caller roles | Idempotency | Result |
|---|---|---|---|---|
| `resolve_customer_by_phone` | Find customer by normalized phone | Sales/Operations/Admin | No — read-only | Customer identity/profile row |
| `create_order` | Create customer/order/items/events/audit record | Sales/Operations/Admin | Required | `order_id`, `order_number`, `customer_id` |
| `confirm_order` | Draft → Confirmed | Sales/Operations/Admin | Required | `order_id`, `order_number`, `lifecycle_state` |
| `cancel_order` | Draft/Confirmed → Cancelled | Sales/Operations/Admin | Required | `order_id`, `order_number`, `lifecycle_state` |
| `cancel_parcel` | Prepared parcel → Cancelled | Authenticated operational roles; final role matrix applies | Required | `parcel_id`, `parcel_number`, `state` |

The following are internal idempotency helpers rather than browser-facing business commands:

- `claim_command_idempotency`
- `complete_command_idempotency`

They exist to support deterministic command retries and must not become an alternate business-write API.

## 5. `resolve_customer_by_phone`

### Input

```text
p_phone: text, required, non-blank
```

### Validation

- authenticated identity required;
- active application role required;
- phone must be non-blank;
- lookup uses normalized phone digits/`+` representation.

### Result

```text
customer_id: uuid
customer_code: text
name: text
phone: text
normalized_phone: text
address: text
city: text
```

No business state is mutated and no idempotency record is required.

## 6. `create_order`

### Input

```text
p_customer_name: text, required
p_phone: text, required
p_address: text, nullable
p_city: text, nullable
p_original_amount: numeric(12,2), required, >= 0
p_items: jsonb array, required, non-empty
p_notes: text, nullable
p_idempotency_key: text, required, non-blank
```

### Item schema

Each item must contain:

```text
description: non-blank text
quantity: positive integer
```

### Result

```text
order_id: uuid
order_number: text
customer_id: uuid
```

### Side effects

Creates/updates the customer as required, creates a Draft order and order items, writes `OrderCreated`, writes an audit record, and completes the idempotency record.

Generated customer/order identifiers are database-owned.

## 7. `confirm_order`

### Input

```text
p_order_id: uuid, required
p_idempotency_key: text, required, non-blank
```

### Preconditions

- caller has Sales/Operations/Admin application role;
- order exists;
- lifecycle state is `Draft`;
- order has at least one item.

### Result

```text
order_id: uuid
order_number: text
lifecycle_state: "Confirmed"
```

### Side effects

Updates the lifecycle state atomically, records `OrderConfirmed`, writes an audit record, completes idempotency, and returns the committed result.

## 8. `cancel_order`

### Input

```text
p_order_id: uuid, required
p_idempotency_key: text, required, non-blank
```

### Preconditions

- authenticated active application role;
- order exists;
- order lifecycle state is `Draft` or `Confirmed`;
- no parcel for the order has reached dispatch or later.

Cancellation is intentionally role-unrestricted among the three application roles; lifecycle/financial preconditions remain mandatory.

### Result

```text
order_id: uuid
order_number: text
lifecycle_state: "Cancelled"
```

### Side effects

Changes order state to Cancelled, reverses active allocations for Prepared parcels, cancels Prepared parcels, records the cancellation event and audit record, completes idempotency, and returns the committed result.

## 9. `cancel_parcel`

### Input

```text
p_parcel_id: uuid, required
p_idempotency_key: text, required, non-blank
```

### Preconditions

- authenticated active application role;
- parcel exists;
- parcel state is `Prepared`.

### Result

```text
parcel_id: uuid
parcel_number: text
state: "Cancelled"
```

### Side effects

Reverses active parcel allocations, changes the parcel to Cancelled, records the parcel cancellation event and audit record, completes idempotency, and returns the committed result.

## 10. Common error contract

Commands must expose stable error categories rather than leaking database implementation details.

| Category | Meaning | Current PostgreSQL class used by commands |
|---|---|---|
| Authentication/authorization | Missing identity, inactive role, or insufficient application role | `42501` |
| Invalid input | Required value missing or malformed | `22023` |
| Not found | Referenced business record does not exist | `P0002` |
| Lifecycle/business rule | Operation is not valid for current state | `P0001` |
| Invariant/constraint | Domain integrity would be violated | Constraint error / documented domain error |
| Idempotency conflict | Same key reused with a different request | `22023` |

The API layer should map these to deterministic client-safe error responses while preserving a server-side diagnostic/audit trail where appropriate.

## 11. Idempotency contract

For every repeatable state-changing command:

1. validate identity, role, required inputs, and idempotency key;
2. derive a request hash from the business inputs;
3. claim `(actor_id, command_name, idempotency_key)`;
4. reject a different request hash for an existing key;
5. return the stored result if the prior execution is already `Completed`;
6. otherwise execute the transaction;
7. persist the committed result as `Completed`;
8. return the same result shape on retry.

Idempotency records are keyed by actor as well as command/key, preventing one authenticated user from replaying another user's command result.

## 12. Audit/event contract

State-changing commands must preserve actor identity and write the domain event/audit record in the same transaction as the business mutation. The API must not report success before the database transaction commits.

## 13. Identifier contract

Commands accept business record IDs only where needed to identify an existing record. They do not accept generated customer/order/parcel numbers for creation. Database-generated identifiers are returned in command results.

## 14. Concurrency contract

Commands that change lifecycle or allocation state must lock the relevant business rows and rely on the established database invariants. The API layer must not implement a read-then-write sequence that bypasses the transactional command.

## 15. Internal helper boundary

`claim_command_idempotency` and `complete_command_idempotency` are database implementation helpers. Their signatures are stable database contracts, but they are not intended as browser-facing endpoints. Direct `EXECUTE` exposure must follow the T043 grant contract and be hardened where current staging grants exceed the target boundary.

## 16. Current implementation comparison

The version-controlled migrations currently implement the core command schemas above, including idempotency-aware signatures for `create_order`, `confirm_order`, `cancel_order`, and `cancel_parcel`. The earlier pre-idempotency signatures are explicitly dropped by the retrofit migration.

The current staging database should be treated as implementation evidence, not the source of the API contract. Any mismatch between staging and this schema registry is a Phase 3 implementation/security issue unless it represents a genuine Phase 2 architecture conflict.

## 17. Phase 3 mapping

Phase 3 implementation must add or harden commands for the remaining capability matrix, including shipment assignment/dispatch, RTO/Lost/Damaged, COD receipt/exception resolution, financial adjustments, imports, user/settings administration, and other required lifecycle transitions. Each command must receive an explicit schema, authorization boundary, idempotency decision, transaction/audit behavior, and positive/negative security tests before being exposed.

## 18. T044 decision

**FORMALIZED — command/API schema contract established from the version-controlled command implementation and locked authorization/idempotency contracts.**

This task does not claim that every future Phase 3 command is implemented.
