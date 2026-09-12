# Audit and Event Taxonomy — T045

## 1. Purpose

This document formalizes the audit-log and domain-event taxonomy for the E-Commerce Operations MVP. It distinguishes business events from security/audit evidence, defines stable event names, required actor/entity fields, and rules for immutable historical evidence.

## 2. Two evidence streams

### Domain events — `public.order_events`

Domain events describe meaningful business-state or operational events attached to an order and optionally a parcel. They are part of the business history and must be append-only.

### Audit logs — `public.audit_logs`

Audit logs record who performed a protected application action and the before/after evidence where applicable. They are security/operational evidence and must be append-only.

A domain event and an audit log may both be written for one command. They serve different purposes and should not be treated as interchangeable.

## 3. Common event structure

### Domain event

Required fields:

- `id` — immutable UUID
- `order_id` — authoritative order relationship
- `parcel_id` — nullable authoritative parcel relationship
- `event_type` — stable taxonomy value
- `event_time` — database timestamp
- `performed_by` — authenticated actor
- `notes` — optional human-readable context
- `metadata` — structured JSON context

### Audit record

Required fields:

- `id` — immutable UUID
- `actor` — authenticated actor where available
- `action` — stable command/action name
- `entity_type` — stable entity category
- `entity_id` — affected entity where applicable
- `before_data` — pre-change evidence where applicable
- `after_data` — post-change evidence where applicable
- `request_id` — correlation identifier where available
- `occurred_at` — database timestamp

## 4. Stable domain-event taxonomy

| Event type | Category | Entity | Meaning | Current implementation |
|---|---|---|---|---|
| `OrderCreated` | Order lifecycle | Order | Draft order created | Implemented |
| `OrderConfirmed` | Order lifecycle | Order | Draft transitioned to Confirmed | Implemented |
| `OrderCancelled` | Order lifecycle | Order | Order transitioned to Cancelled | Implemented |
| `ParcelCancelled` | Parcel lifecycle | Parcel | Prepared parcel transitioned to Cancelled | Implemented |
| `ParcelPrepared` | Parcel lifecycle | Parcel | Parcel became prepared for execution | Reserved for Phase 3 implementation |
| `ParcelDispatched` | Shipment lifecycle | Parcel | Parcel dispatched | Reserved for Phase 3 implementation |
| `ParcelInTransit` | Shipment lifecycle | Parcel | Parcel entered transit | Reserved for Phase 3 implementation |
| `DeliveryNDR` | Delivery exception | Parcel | Delivery attempt resulted in NDR | Reserved for Phase 3 implementation |
| `ParcelDelivered` | Delivery outcome | Parcel | Parcel delivered | Reserved for Phase 3 implementation |
| `ParcelRTO` | Delivery outcome | Parcel | Parcel entered RTO | Reserved for Phase 3 implementation |
| `ParcelLost` | Delivery exception | Parcel | Parcel recorded as lost | Reserved for Phase 3 implementation |
| `ParcelDamaged` | Delivery exception | Parcel | Parcel recorded as damaged | Reserved for Phase 3 implementation |
| `ShipperAssigned` | Fulfillment | Parcel | Shipper assigned to parcel | Reserved for Phase 3 implementation |
| `CODObligationCreated` | COD | Order | COD obligation established | Reserved for Phase 3 implementation |
| `CODReceiptRecorded` | COD | Parcel | Receipt recorded for parcel | Reserved for Phase 3 implementation |
| `CODExceptionOpened` | COD exception | Order/Parcel | COD discrepancy entered exception state | Reserved for Phase 3 implementation |
| `CODExceptionResolved` | COD exception | Order/Parcel | COD exception resolved by authorized actor | Reserved for Phase 3 implementation |
| `FinancialAdjustmentRecorded` | Finance | Order/Parcel | Financial delta recorded | Reserved for Phase 3 implementation |
| `InvoiceGenerated` | Invoice | Order | Invoice record generated | Reserved for Phase 3 implementation |
| `ImportStarted` | Import | Import batch | Historical import began | Reserved for Phase 3 implementation |
| `ImportCompleted` | Import | Import batch | Historical import completed | Reserved for Phase 3 implementation |
| `ImportFailed` | Import | Import batch | Historical import failed | Reserved for Phase 3 implementation |
| `ImportRolledBack` | Import | Import batch | Import rollback completed | Reserved for Phase 3 implementation |

Reserved values are architectural vocabulary, not claims that those operations are currently implemented.

## 5. Event naming rules

1. Use stable PascalCase names.
2. Name events as facts that have occurred, not commands or UI actions.
3. Use one canonical event name for one business meaning; do not create synonyms such as `OrderCanceled` versus `OrderCancelled`.
4. Event names must not encode actor role or UI screen.
5. Lifecycle transitions should capture `from` and `to` in `metadata` when that context is material.
6. Exception/outcome events should preserve the authoritative parcel/order relationship.
7. Corrections append a new fact/event; they do not rewrite an old event.

## 6. Audit action naming rules

Audit `action` values should normally equal the protected command or administrative action that caused the mutation, for example:

- `create_order`
- `confirm_order`
- `cancel_order`
- `cancel_parcel`
- future shipment, COD, financial, import, administration command names as defined by their API contracts.

Audit actions describe the operation performed; domain event types describe the resulting business fact. They should not be collapsed into one namespace.

## 7. Actor rules

- `performed_by` / `actor` must preserve the authenticated application actor.
- Application roles are resolved from the authoritative profile/role boundary, not from browser-supplied labels.
- Service-role infrastructure execution must preserve the originating business actor where an application command is being executed on their behalf.
- Anonymous callers must not create protected business events or audit records.

## 8. Transactional rules

For state-changing commands:

`validate → mutate → append domain event → append audit record → complete idempotency → commit`

The API must not report success before the transaction commits. A failed business transaction must not leave a successful event/audit record representing a mutation that did not commit.

## 9. Immutability and correction

Domain events and audit logs are historical evidence. Normal application roles must not update or delete them. Corrections must be represented by a new authorized command and corresponding event/audit evidence.

## 10. Idempotency interaction

A retry of the same command must return the previously committed result and must not append a duplicate domain event or duplicate audit record. A new command execution with a new idempotency key creates its own evidence.

## 11. Metadata rules

Metadata should contain structured, non-secret operational context needed to explain the event. Never store passwords, access tokens, service-role keys, or unnecessary personal/secrets data in event metadata or audit snapshots.

Where before/after data is required, record the minimum evidence necessary to establish the state transition.

## 12. Current implementation baseline

The current version-controlled command implementation writes `OrderCreated`, `OrderConfirmed`, `OrderCancelled`, and `ParcelCancelled`, together with corresponding audit actions. The database foundation defines the event/audit tables and their actor/entity relationships.

The remaining taxonomy entries are reserved vocabulary for later Phase 3+ implementation and must not be treated as implemented solely because they are listed here.

## 13. T045 decision

**FORMALIZED — audit and domain-event taxonomy established.**

This task establishes the architecture contract; implementation of reserved event-producing commands remains governed by the later implementation milestones.
