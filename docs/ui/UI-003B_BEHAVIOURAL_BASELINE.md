# UI-003B — Behavioural Baseline

**Project:** E-Commerce Operations  
**Master Plan:** UI-MP-1.2  
**Protected baseline:** `dd6fe0227bec898889fb835e38c2f990dc34be07`  
**UI audit branch:** `ui/ui-mp-1.2-baseline-contract-audit`  
**Evidence commit for this baseline:** `fb09048307b5d497d3b68fcc776cbd3e43f5b5f9`

## 1. Purpose

This document freezes the behaviour that the UI modernization must preserve. It is a presentation baseline, not a redesign specification.

The baseline is derived from repository source inspection and the existing automated test suite. Browser execution against the deployed preview was **NOT VERIFIED** in this gate because the available web retrieval path could not access the Cloudflare preview URL. Existing Playwright test definitions are recorded as repository evidence; this document does not claim a fresh browser run unless explicitly marked below.

## 2. Verification status

| Area | Status | Basis |
|---|---|---|
| Authenticated shell | VERIFIED by source/tests | `src/App.tsx`, auth tests, T227 E2E definitions |
| Lazy workspace mounting | VERIFIED by source/tests | `src/App.tsx`, `ui004_workspace_loading.test.mjs` |
| Orders search/filter/pagination | VERIFIED by source/tests | `OrdersWorkspace.tsx`, `orders_workspace.test.mjs`, `orders_date_views.test.mjs` |
| Draft edit/confirm | VERIFIED by source/tests | `pre_confirmation_order_editing.test.mjs`, `order_confirmation.test.mjs` |
| Order export | VERIFIED by source/tests | `order_export.test.mjs` |
| Dispatch / RTO / Delivery / COD / Invoice / Reports / Admin contracts | VERIFIED by source inspection | UI-002 contract inventory and component source |
| Fresh browser execution on current preview | NOT VERIFIED | Preview URL was not accessible through the available browser retrieval path |
| Real-user UAT with staging credentials | NOT VERIFIED | No new staging credential/browser session was introduced by UI-003B |

## 3. Global shell behaviour

### Authentication boundary

1. Unauthenticated access presents the authentication boundary.
2. If authentication is not configured, the UI explicitly states that no demo account/business data is being fabricated.
3. If configured, the login form requires email and password.
4. Successful sign-in establishes the authenticated session and navigates to the requested safe post-login path.
5. Sign-out clears the operational session and returns to `/login`.
6. Authenticated workspaces require an access token.
7. Admin-only controls remain gated by the existing `canAdministerUsers` check.

### Workspace mounting

1. The active workspace is controlled by the top-level `activeWorkspace` state.
2. Authenticated workspaces are lazy-loaded.
3. A Suspense loading state is displayed while a workspace module loads.
4. Only the active workspace is mounted in normal UI operation.
5. Diagnostic T227 controls are intentionally separate from normal startup behaviour and must not become part of the production information architecture.

Existing T227 Playwright coverage defines isolated workspace mounting for Orders, Customers, Dispatch, RTO, Invoices, Reports and Admin and checks for page/request errors.

## 4. Dashboard / Home baseline

Authenticated Dashboard currently provides:

- customer lookup by phone;
- customer name;
- city;
- address;
- order items;
- item description;
- positive whole-number quantity;
- one total order amount in AED;
- optional notes;
- Create Draft Order;
- transactional success/error feedback;
- operational foundation/status cards.

The draft-order form must continue to submit the existing `create_order` command.

The total amount remains a single manual AED total. The UI must not introduce item prices, VAT, discounts, service fees, or calculated commercial subtotals.

## 5. Customers baseline

The Customers workspace:

- resolves a customer by phone;
- retrieves customer history;
- displays customer identity information;
- displays order history including order number, date, lifecycle state and original amount;
- requires authenticated access.

A visual redesign must not invent customer analytics that are not supplied by the existing contract.

## 6. Orders baseline

### List

Orders currently supports:

- server-side search;
- lifecycle-state filter;
- parcel-state filter;
- COD-state filter;
- quick date views;
- custom date range;
- pagination;
- refresh;
- order export;
- order detail/editor;
- timeline;
- Draft Edit;
- Draft Confirm.

Page size is 25.

### Search

Search is intended for:

- order ID/order number;
- customer name;
- phone;
- address;
- item description.

Search remains server-side and must preserve safe input handling.

### Filters

Lifecycle values:

- Draft
- Confirmed
- Active
- Completed
- Cancelled

Parcel values:

- Prepared
- Dispatched
- In Transit
- NDR
- Delivered
- RTO
- Lost
- Damaged
- Cancelled

COD values:

- Outstanding
- Partially Received
- Received
- Exception
- Voided
- Closed

### Date views

Orders exposes:

- All dates
- Today
- Yesterday
- Last 7 Days
- Last 30 Days
- Custom

Custom ranges must reject an inverted from/to range.

### Draft actions

Draft orders can be:

- edited;
- saved;
- confirmed.

Confirmed and later lifecycle states must not expose Draft-only editing/confirmation controls.

Confirmation remains a transactional, idempotent command and must not be replaced by client-side state mutation.

## 7. Parcel / allocation baseline

The current command contract supports:

- parcel creation;
- item allocation;
- split allocation;
- allocation correction;
- parcel cancellation;
- shipper assignment;
- tracking-ID uniqueness validation;
- dispatch;
- delivery outcomes;
- RTO;
- NDR retry.

The modernization must preserve these semantics.

There is no verified dedicated parcel list/detail workspace in the top-level App navigation at this baseline. Do not create a new functional parcel workflow merely to fill a visual navigation slot.

## 8. Dispatch baseline

Dispatch is scan-first.

Expected flow:

1. operator enters/scans a barcode;
2. parcel is resolved;
3. parcel state is displayed;
4. assigned shipper is displayed;
5. tracking ID is displayed;
6. dispatch is permitted only when the existing eligibility conditions are satisfied;
7. dispatch result is shown.

Current UI eligibility is:

- state = Prepared;
- active assigned shipper exists;
- tracking ID exists.

The UI must continue to distinguish:

- unknown barcode;
- duplicate/already-dispatched scan;
- not-ready state;
- missing shipper/tracking information;
- successful dispatch;
- command failure.

Camera scanning is **not** part of the current contract.

## 9. Bulk Dispatch baseline

Bulk dispatch must preserve:

- multiple parcel resolution;
- Prepared-only eligibility;
- active assigned shipper;
- existing tracking ID;
- duplicate prevention;
- per-parcel idempotency;
- batch submission;
- per-parcel success/failure result;
- retryability of failed items.

The visual redesign must not collapse partial success/failure into one binary batch result.

## 10. Delivery / NDR baseline

From In Transit, the current outcome workflow supports:

- Delivered;
- NDR;
- Lost;
- Damaged.

From NDR, it supports:

- Delivered;
- Retry NDR.

Retry NDR returns the parcel to In Transit through the existing command.

Terminal states include:

- Delivered;
- RTO;
- Lost;
- Damaged;
- Cancelled.

Do not add an Out for Delivery state unless it is separately verified in the authoritative contract.

## 11. RTO baseline

RTO processing is scan-first.

Eligible states:

- In Transit;
- NDR.

The stored shipper is resolved automatically by the existing command. The operator must not be required to select a historical shipper.

Bulk RTO processes parcels independently and must retain per-parcel results.

## 12. COD & Finance baseline

Current workflow:

1. resolve order;
2. create COD obligation;
3. allocate obligation to parcel;
4. record receipt;
5. show receipt/financial state;
6. allow Admin exception resolution;
7. allow Admin reconciliation view.

Admin-only functions must remain unavailable to non-admin users.

The redesign must not add new financial calculations or alter authoritative reconciliation values.

## 13. Invoices baseline

Current invoice workspace supports:

- refresh;
- individual selection;
- select all;
- individual PDF download;
- selected batch PDF download;
- individual print;
- selected batch print.

Invoices are generated from stored historical invoice snapshots and template versions.

Print actions are recorded using the existing `record_invoice_print` command with `individual` or `batch` mode.

The validated PDF/print generation path remains protected. Visual redesign must not change filename semantics, snapshot source, template version, or print-event recording.

## 14. Reports baseline

The Reports workspace currently exposes 11 report sources:

- Order Summary
- Parcel Operations
- Delivery Outcomes
- COD & Financial Reconciliation
- Historical Import Reconciliation
- Orders Detail
- Parcel & Delivery
- Customer Activity
- COD & Financial Reconciliation Detail
- Historical Import Reconciliation Detail
- Reconciliation Exceptions

Current controls:

- Refresh reports;
- All dates;
- Today;
- Yesterday;
- Last 7 days;
- Last 30 days;
- Custom;
- Export Excel.

Only the first 25 filtered rows are displayed in each report table. Excel export includes the complete filtered dataset.

Reports without an authoritative date column are not date-filtered.

Do not introduce trend percentages, invented KPIs, charts or derived business metrics merely to match a visual mockup.

## 15. Admin baseline

Admin Users is visible only when the authenticated profile passes the existing admin check.

Current functions:

- load application profiles;
- link an existing Auth user ID;
- assign Sales, Operations or Admin role;
- activate/deactivate application profiles.

Auth identity deletion and password-management functions are not part of this UI contract.

## 16. Required shared states

Every redesigned workspace must preserve an explicit presentation for the states applicable to its contract:

- loading;
- success;
- error;
- empty;
- validation;
- disabled/busy;
- permission denied;
- unknown barcode;
- duplicate scan;
- wrong lifecycle state;
- terminal state;
- partial batch success/failure;
- request/network failure.

Accessibility work must provide appropriate live-region announcements for operational scan/result feedback without changing command behaviour.

## 17. Responsive baseline

Target viewports:

- 390 × 844;
- 430 × 932;
- 768 × 1024;
- 1280+.

Responsive redesign may use different information architecture on mobile and desktop, but the same workflows, state transitions, permissions and command contracts must remain available.

Visual direction remains locked as:

- Clean Modern SaaS foundation;
- Modern Operations primary language;
- selective Logistics Command Center treatment for scan/field surfaces.

## 18. Regression rules for UI implementation

Before any UI screen is declared complete:

1. Existing command/API calls remain unchanged.
2. Existing authorization checks remain unchanged.
3. Existing lifecycle/state constraints remain unchanged.
4. Existing error/empty/loading behaviour remains represented.
5. Existing export/print/download behaviour remains available.
6. Existing test contracts remain green.
7. No protected path is modified unless the separate scope-exception process is used.
8. Mobile and desktop layouts are checked at the locked target viewports.
9. No unsupported data is introduced to make a mockup appear complete.

## 19. UI-003B completion criterion

UI-003B is complete when the current behaviour is documented sufficiently to act as the regression baseline for UI implementation, with unsupported assumptions explicitly marked as NOT VERIFIED.

**Status: COMPLETE — source/test behavioural baseline established.**

Browser-level fresh execution remains a separate verification item and must not be represented as completed by this document.
