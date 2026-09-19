# E-Commerce Operations — Locked Report Specifications

**Milestone:** P13-T199  
**Phase:** 13 — Reports  
**Status:** Draft for Business Owner acceptance  
**Source of truth:** Master Implementation Plan v4.0 and the authoritative database/domain contracts already implemented in the repository.

## 1. Scope

This document locks the business meaning and minimum output contract for Phase 13 reporting. Later milestones (P13-T200 through P13-T206) may implement, optimize, render, export, and test these specifications, but must not silently change their business definitions.

The reporting layer is read-only. It must use authoritative order, parcel, delivery-outcome, COD, financial-adjustment, customer, and historical-import data. It must not maintain competing business state.

The Master Implementation Plan requires summary queries/views for Dashboard and Reports, server-side pagination for operational data, and verification of report calculations against authoritative data.

## 2. Common report contract

Every report must define:

- Report name and purpose.
- Requested date range and timezone semantics.
- Authoritative source tables/views/queries.
- Row grain (one row per order, parcel, customer, receipt, adjustment, or import row as applicable).
- Required filters.
- Required columns and business definitions.
- Null/unknown-state treatment.
- Currency treatment: AED and original monetary values; no derived VAT, discount, unit-price, or service-fee assumptions.
- Export behavior to be implemented in P13-T203.

Unless a report explicitly states otherwise, date filtering is based on the authoritative business timestamp for that report's grain and uses the application's locked timezone policy.

## 3. Locked report set

### RPT-01 — Order Summary / Orders Report

**Purpose:** operational view of commercial order activity.

**Grain:** one row per order.

**Required measures/fields:**
- Order ID / order number.
- Order date/time.
- Customer identity reference and customer name.
- City.
- Original Total Order Amount.
- Current lifecycle state.
- Parcel count.
- Delivered/RTO/Lost/Damaged parcel outcome summary where available.
- Created/updated timestamps as appropriate.

**Filters:** date range, lifecycle state, city, customer, and order identifier/search term.

**Rules:** original order amount is immutable; report calculations must not reconstruct order value from invented unit prices or VAT/discount fields.

### RPT-02 — Parcel & Delivery Operations Report

**Purpose:** physical fulfillment and delivery performance view.

**Grain:** one row per parcel.

**Required fields:**
- Parcel number / barcode.
- Order number.
- Parcel state.
- Shipper.
- Unique tracking ID.
- Dispatch timestamp where applicable.
- Delivery/NDR/RTO/Lost/Damaged outcome information where applicable.
- Delivered amount where applicable.
- Relevant outcome timestamp.

**Filters:** date range, parcel state, shipper, tracking ID, order number, and outcome type.

**Rules:** NDR is non-terminal; Lost and Damaged are terminal physical outcomes. The report must not treat NDR as a terminal delivery result.

### RPT-03 — Customer Activity Report

**Purpose:** customer/order activity and repeat-customer analysis.

**Grain:** one row per customer for summary output; drill-down may expose related orders.

**Required measures/fields:**
- Customer ID/code.
- Customer name.
- Normalized phone.
- City.
- Order count.
- First order date.
- Latest order date.
- Total original order amount across included orders.
- Current/open order count where applicable.

**Filters:** date range, city, customer, normalized phone, and order activity state.

**Rules:** customer identity is based on the canonical normalized phone model. Historical rows with missing/unreliable phones remain controlled exceptions rather than being fuzzy-matched.

### RPT-04 — COD & Financial Reconciliation Report

**Purpose:** reconcile COD obligations/receipts and authorized financial adjustments.

**Grain:** one row per COD obligation/receipt allocation as appropriate, with summary totals.

**Required measures/fields:**
- Order and parcel references.
- COD obligation amount.
- Receipt amount.
- Delivered/collected amount where authoritative.
- Variance.
- Exception/resolution state where applicable.
- Financial adjustments and effective amount where applicable.
- Reconciliation status.

**Filters:** date range, reconciliation state, variance state, shipper, order number, parcel number.

**Rules:** one COD receipt maximum per parcel; original receipt remains immutable; financial corrections are append-only adjustments. Totals must reconcile to authoritative stored values.

### RPT-05 — Historical Import Reconciliation Report

**Purpose:** audit historical-import completeness and reconciliation.

**Grain:** one row per import batch for summary, with drill-down to import rows.

**Required measures/fields:**
- Batch ID.
- Source system.
- Source file.
- Initiated timestamp / actor.
- Batch status.
- Total source rows.
- Valid/error counts.
- Create/matched/exception counts.
- Reconciliation result.
- Monetary source/import totals where configured.
- Error-report availability.

**Filters:** batch, source system, source file, status, and date range.

**Rules:** source row numbers, raw source data, deterministic source identity, and error information remain traceable to the batch. Reports must not mutate import data.

### RPT-06 — Reconciliation / Exceptions Report

**Purpose:** operational list of unresolved mismatches and controlled exceptions requiring attention.

**Grain:** one row per reconciliation exception or unresolved operational exception.

**Required fields:**
- Exception category.
- Entity type and identifier.
- Related order/parcel/customer/batch reference.
- Expected value/count.
- Actual value/count.
- Variance where monetary/count comparison applies.
- Current resolution state.
- Created/updated timestamp.
- Responsible operational/admin context where recorded.

**Filters:** date range, exception category, resolution state, entity identifier.

**Rules:** this report is a projection of authoritative exception/reconciliation data; it does not become a second source of truth.

### RPT-07 — Audit & Event History Report

**Purpose:** trace operational and privileged activity without editing historical records.

**Grain:** one row per event/audit record.

**Required fields:**
- Timestamp.
- Actor.
- Event/action type.
- Entity type and identifier.
- Before/after data where recorded.
- Metadata/request context where recorded and safe to expose.

**Filters:** date range, actor, action/event type, entity type, entity identifier.

**Rules:** historical events and security audit records are immutable. Sensitive secrets, tokens, passwords, and unnecessary personal data must not be exposed.

## 4. KPI definitions reserved for P13-T200

The KPI layer must use the above report definitions and authoritative data. At minimum it must provide counts/totals that can be independently reproduced from the underlying authoritative queries, including:

- Orders by lifecycle state.
- Order value totals using immutable Original Total Order Amount.
- Parcel counts by physical state/outcome.
- Delivery/NDR/RTO/Lost/Damaged counts.
- COD obligation/receipt/variance totals.
- Financial adjustment totals.
- Historical import row/create/matched/error/reconciliation totals.

A KPI must not be introduced merely because it is convenient to calculate; its business definition and authoritative source must be explicit.

## 5. Filter and date rules

All later report implementations must preserve:

1. Explicit date-range filtering.
2. Inclusive start / exclusive end semantics for timestamp ranges unless the implementation specification for a particular report states a more precise equivalent.
3. Locked application timezone policy rather than browser-local reinterpretation.
4. Server-side filtering/pagination for large operational datasets.
5. Stable ordering for paginated results.
6. Explicit handling of null/unknown values.

## 6. Export contract

P13-T203 will implement Excel export against these same report definitions. Exported values must equal the values shown by the corresponding report query for the same filters and date range. Export must not introduce additional business calculations.

## 7. Calculation authority

P13-T204 must verify every report calculation against the authoritative tables/queries. Where a derived value conflicts with a stored authoritative value, the implementation must stop and resolve the source/query discrepancy rather than silently changing the business definition.

## 8. Acceptance gate for P13-T199

Business Owner acceptance requires confirmation that:

- The report set and purposes are correct.
- The row grain of each report is correct.
- Required fields/measures are correct.
- Filter and date behavior is acceptable.
- No prohibited financial fields or assumptions have been introduced.
- The definitions may be implemented in P13-T200 through P13-T206 without further business-definition changes.

**Acceptance status: Pending Business Owner approval.**
