# E-Commerce Operations MVP — Project Glossary

**Status:** Locked Phase 2 architecture baseline
**Task:** P2-T031A
**Baseline:** Master Implementation Plan v4.0 Final
**Date:** 2026-09-13

## Purpose

This glossary defines the business and architecture terminology used by the E-Commerce Operations MVP. It is derived from the locked business blueprint, technical development plan, and Master Implementation Plan v4.0. Terms below are normative for implementation, tests, documentation and operational discussion.

## Core business terms

| Term | Definition |
|---|---|
| Customer | Identity/contact record representing a buyer and their order history. |
| Order | The single authoritative commercial record for a transaction. |
| Order Item | A line representing what was sold, including its original ordered quantity and original line value. |
| Parcel | A physical package belonging to one order and carrying its own operational lifecycle. |
| Parcel Item | The exact quantity of an Order Item allocated to a specific Parcel. |
| Shipper | Courier/carrier responsible for a parcel movement. |
| Delivery Outcome | Operational result recorded for a parcel, including Delivered, RTO, Lost, Damaged or NDR. |
| COD Obligation | The expected cash-on-delivery amount associated with the order/parcel operation. |
| COD Receipt | Record of money actually collected against a COD operation. |
| Financial Adjustment | An authorized, additive exception to an original commercial value; it does not rewrite the original amount. |
| Invoice Record | Record of generated/printed invoice lineage, including template version and print history. |
| Order Event | Immutable operational history describing a significant order/parcel action. |
| Audit Log | Security/change-accountability record containing actor, action and before/after context where applicable. |
| Import Batch / Import Row | Historical-data ingestion records preserving source lineage, validation and import status. |
| User / Profile | Application identity associated with an authenticated user and application role. |

## Order and parcel lifecycle terms

| Term | Definition |
|---|---|
| Draft | Initial order lifecycle state in which permitted pre-confirmation editing is allowed. |
| Confirmed | Order state reached after required customer, amount and item validation succeeds. |
| Active | Order lifecycle state representing an order continuing through physical fulfilment. |
| Completed | Terminal successful order lifecycle state. |
| Cancelled | Terminal cancelled state; historical transactional records remain searchable and are not hard-deleted. |
| Prepared | Parcel is created/prepared but has not been dispatched. |
| Dispatched | Parcel has been handed over for dispatch. |
| In Transit | Parcel is moving through fulfilment after dispatch. |
| Delivered | Parcel has reached a delivered outcome. |
| RTO | Return-to-origin outcome for a parcel. |
| NDR | Non-delivery report; a non-terminal delivery outcome that permits a subsequent attempt or another valid outcome. |
| Lost | Parcel outcome indicating loss in transit/operations. |
| Damaged | Parcel outcome indicating damage in transit/operations. |
| Partial Delivery | Delivery resolved for only part of an order/item quantity. |
| Partial RTO | RTO resolved for only part of an order/item quantity. |

## Financial terminology

| Term | Definition |
|---|---|
| Original Amount | The original commercial amount recorded for an order/item and preserved as historical truth. |
| Total Order Amount | The order-level commercial amount used for confirmation and later financial interpretation according to the locked financial contract. |
| Service Fee | Order-level fee component included in the financial calculation. |
| Discount | Order-level reduction component. |
| VAT | Value-added-tax component governed by the locked VAT/rounding contract. |
| Actual Delivered Amount | Amount actually attributable to delivered goods when an authorized financial exception is recorded; original commercial value remains preserved. |
| Adjustment | Additive financial record used to represent an exception rather than overwriting historical values. |
| Variance | Difference between expected and received COD amounts requiring the defined exception process. |
| AED | United Arab Emirates dirham, the MVP currency. |

## Identity and data terminology

| Term | Definition |
|---|---|
| Normalized Phone | Canonical UAE mobile representation used for customer matching and uniqueness enforcement, formatted as `+971XXXXXXXXX`. |
| Customer Code | Unique customer identifier. |
| Order Number | Unique order identifier generated according to the identifier/sequence contract. |
| Parcel Number | Unique parcel identifier; the parcel barcode equals the parcel number in the MVP contract. |
| Tracking ID | Globally unique carrier tracking identifier. |
| Line Number | Stable order-item line position within an order. |
| Historical Data | Existing transactional data imported through the staged migration process while remaining searchable in the application. |

## Architecture and security terms

| Term | Definition |
|---|---|
| Authoritative State | The PostgreSQL-backed business state that is the single source of truth for transactional lifecycle and financial rules. |
| Command | A server-side operation that changes business state only after authorization, current-state validation and business-invariant validation. |
| Query | Read operation that does not change authoritative business state. |
| Idempotency | Deterministic handling of repeated requests so the same critical operation is not applied more than once. |
| RLS | PostgreSQL Row Level Security used to enforce row-level data access rules. |
| SECURITY DEFINER | PostgreSQL function execution mode used for controlled privileged application commands, combined with explicit authorization and a pinned search path. |
| Least Privilege | Granting actors only the database/application capabilities required for their role. |
| Application Role | Business authorization role: Sales, Operations or Admin. |
| Sales | Role responsible primarily for customer/order work and permitted sales-side operational updates. |
| Operations | Role responsible primarily for fulfilment, invoice, shipper, dispatch and parcel operations. |
| Admin | Role with full operational capabilities plus users, settings, imports/exports, reports and exceptional corrections as authorized. |
| Auditability | Ability to reconstruct security-sensitive changes and operational history from durable records. |
| Append-only | Historical record model in which existing events/adjustments cannot be rewritten or deleted through ordinary application access. |

## Data and implementation concepts

| Term | Definition |
|---|---|
| Allocation | Quantity relationship assigning an Order Item quantity to a Parcel Item. |
| Allocation Invariant | Total quantity allocated across parcels must not exceed the ordered quantity. |
| Derived Field / View | Value calculated from authoritative underlying records rather than independently edited as competing truth. |
| Event History | Permanent chronological operational record; current state is a convenient derived view. |
| Transaction | Atomic database operation in which validation, state change, event/audit recording and commit succeed together or the business change does not partially commit. |
| Migration | Version-controlled database change applied through the repository migration sequence. |
| Seed Data | Controlled local/test data used to make reproducible development and verification possible. |
| Rebuild Verification | Evidence that the database can be reconstructed from repository-controlled migrations and seed data. |
| Correlation ID / Request ID | Safe identifier connecting a server request and related diagnostic telemetry without using customer PII or secrets. |
| Observability | Diagnostic telemetry covering logs, errors, metrics, traces and alerts; it is not authoritative business history. |

## Environment terminology

| Term | Definition |
|---|---|
| Local | Developer-controlled environment using the repository and local Supabase stack for reproducible development/testing. |
| Preview | Non-production deployment used to validate changes before staging. |
| Staging | Controlled environment for integration, verification and UAT preparation. |
| Production | Live business environment protected by the required phase gates and production-safety controls. |

## Locked architecture principles expressed by terminology

1. **Order-centric commercial record:** the Order is the authoritative commercial record.
2. **Parcel-centric physical operations:** dispatch, delivery and RTO operate on Parcels.
3. **Items preserve what was sold:** original quantity and original value are not rewritten to represent later physical outcomes.
4. **Financial exceptions are additive:** adjustments preserve the original commercial amount and record the exception separately.
5. **State changes are command-driven:** business state is not changed by arbitrary browser-side status edits.
6. **History is permanent:** important operational events and security audit records are durable and append-only where defined.
7. **No competing sources of truth:** reports and UI views consume authoritative business data rather than reimplementing independent calculations.

## Source basis

- E-Commerce Operations Application — Final MVP Blueprint v1.0
- E-Commerce Operations Application — Technical Development & Implementation Plan v1.0
- E-Commerce Operations Application — Master Implementation Plan v4.0 Final

This glossary is a Phase 2 architecture artifact. Changes to locked terminology that alter business meaning, schema meaning or architecture require the project's normal change-control process.
