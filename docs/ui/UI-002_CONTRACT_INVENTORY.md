# UI-002 — UI Contract Inventory

**Project:** E-Commerce Operations  
**Master Plan:** UI-MP-1.2  
**Baseline commit:** `dd6fe0227bec898889fb835e38c2f990dc34be07`  
**Baseline branch:** `restore/UI-RESTORE-GATE-2026-10-01`  
**UI audit branch:** `ui/ui-mp-1.2-baseline-contract-audit`  
**Audit scope:** UI contract inventory only. No DB, migration, backend, auth, API-contract, business-logic or data changes.

## 1. Inventory method

This inventory is based on repository inspection at the protected baseline commit. It records the contracts the UI currently consumes or presents so the modernization can change presentation without changing application behaviour.

Primary inspected surfaces:

- `src/App.tsx`
- `src/App.css`
- `src/index.css`
- `src/RouteGuard.tsx`
- `src/lib/auth.ts`
- `src/lib/roles.ts`
- `src/lib/AuthContext.tsx`
- `src/lib/routes.ts`
- `src/lib/commands.ts`
- `src/lib/parcelCommands.ts`
- `src/components/OrdersWorkspace.tsx`
- `src/components/DispatchScanWorkspace.tsx`
- `src/components/BulkDispatchWorkspace.tsx`
- `src/components/DeliveryOutcomeWorkspace.tsx`
- `src/components/RtoScanWorkspace.tsx`
- `src/components/BulkRtoWorkspace.tsx`
- `src/components/CodFinanceWorkspace.tsx`
- `src/components/CustomerHistoryWorkspace.tsx`
- `src/components/InvoicePrintWorkspace.tsx`
- `src/components/ReportWorkspace.tsx`
- `src/components/AdminUserControls.tsx`

## 2. Global application contract

### Application shell

`src/App.tsx` owns the current top-level workspace shell.

Current navigation values:

- Dashboard
- Customers
- Orders
- Parcels
- Dispatch
- Delivery / NDR
- COD & Finance
- Invoices
- Reports
- Admin Users (admin only)

The UI redesign may change the presentation and responsive information architecture, but must preserve access to these existing functional surfaces.

### Authentication boundary

`src/RouteGuard.tsx` protects every path except `/login`.

`src/lib/routes.ts` defines:

- public path: `/login`
- protected-path behaviour
- safe return path handling
- post-login redirect

The UI may redesign login/loading/denied states but must not change authentication or authorization semantics.

### Roles

`src/lib/roles.ts` defines the application roles:

- `sales`
- `operations`
- `admin`

`src/lib/auth.ts` defines:

- `hasOperationalAccess`
- `canAdministerUsers`
- authenticated profile shape
- active-profile requirement

Admin-only UI must continue to use the existing authorization check.

## 3. Screen-by-screen contract inventory

### 3.1 Dashboard / Home

**Current owner:** `src/App.tsx`

**Current behaviour:**

- authentication/access presentation
- draft-order creation
- customer lookup by phone
- customer name/address/city
- order items
- integer quantity
- manual total order amount
- optional notes
- create draft order
- foundation/status information
- operational metric placeholders

**Existing command contracts used:**

- `resolve_customer_by_phone`
- `create_order`

**Data constraints:**

- order item = description + integer quantity
- one manual total order amount
- no item-level pricing
- no VAT/discount/service-fee fields in the current form

**UI rule:** Do not invent product images, item prices, subtotal, shipping, notification system, trend calculations or other unsupported data.

### 3.2 Customers

**Owner:** `src/components/CustomerHistoryWorkspace.tsx`

**Props:**

- `accessToken: string`

**Operations:**

- resolve customer by phone
- retrieve customer history

**Commands/API contracts:**

- `resolve_customer_by_phone`
- `GET /api/customers/{customerId}/history`

**Current customer data displayed:**

- customer name
- customer code
- phone
- order history:
  - order number
  - order date
  - lifecycle state
  - original amount

**UI rule:** Preserve the existing history lookup contract. Any richer customer metrics require verification before inclusion.

### 3.3 Orders

**Owner:** `src/components/OrdersWorkspace.tsx`

**Props:**

- `accessToken: string`
- optional `onOrdersChange(orders)`

**Existing list contract:**

`listOrders()` supports:

- page
- page size
- server-side search
- lifecycle state
- parcel state
- COD state
- date from
- date to

Page size is currently 25 in the workspace.

**Search scope stated by UI:**

- order ID
- customer name
- phone
- address
- item description

**Date views:**

- All dates
- Today
- Yesterday
- Last 7 Days
- Last 30 Days
- Custom

**Lifecycle filter values currently represented in UI:**

- Draft
- Confirmed
- Active
- Completed
- Cancelled

**Parcel filter values currently represented in UI:**

- Prepared
- Dispatched
- In Transit
- NDR
- Delivered
- RTO
- Lost
- Damaged
- Cancelled

**COD filter values currently represented in UI:**

- Outstanding
- Partially Received
- Received
- Exception
- Voided
- Closed

**Current operations:**

- search
- filter
- date filter
- pagination
- CSV export
- open detail
- open timeline
- edit Draft
- confirm Draft

**Command contracts:**

- `update_order`
- `confirm_order`
- `GET /api/orders`
- `GET /api/orders/{orderId}/timeline`

**Order data contract:**

- order ID
- order number
- lifecycle state
- original amount
- notes
- order date
- timestamps
- customer object
- order items
- timeline events

**Order item contract:**

- id
- line number
- description
- integer quantity

**Timeline contract:**

- id
- event type
- event time
- performed by
- notes
- metadata
- parcel ID

**UI rule:** State-valid actions must remain state-valid. Confirmed and later states are currently locked for editing in this workspace.

### 3.4 Parcels / allocation

**Current command layer:** `src/lib/parcelCommands.ts`

Verified command contracts include:

- `create_parcel`
- `allocate_parcel_item`
- `allocate_parcel_items`
- `correct_parcel_allocation`
- `cancel_parcel`
- `assign_parcel_shipper`
- `validate_unique_tracking_id`
- `dispatch_parcel`
- `record_delivery_outcome`
- `process_rto`
- `retry_ndr_parcel`

**Verified input/output characteristics:**

- parcel number/barcode
- order ID
- order item ID
- integer allocation quantity
- split allocations
- corrected quantity
- shipper ID/name
- tracking ID and normalized tracking ID
- lifecycle state
- delivery outcome
- NDR retry
- RTO result

**UI rule:** Parcel redesign must preserve allocation, split, correction and cancellation semantics. The current repository inventory does not identify a dedicated parcel list/detail workspace in `App.tsx`; this must be verified before UI-09 implementation.

### 3.5 Dispatch / Scan

**Owner:** `src/components/DispatchScanWorkspace.tsx`

**Props:**

- `accessToken: string`

**Current interaction:**

1. barcode input
2. resolve parcel
3. display parcel state
4. display assigned shipper
5. display tracking ID
6. dispatch only when state/shipper/tracking conditions are satisfied

**Current parcel resolution fields:**

- id
- parcel number
- barcode
- state
- tracking ID
- shipper ID
- shipper id/name/active

**Primary command:**

- `dispatch_parcel`

**Idempotency:** a per-parcel/tracking attempt key is retained for safe retry.

**Current scan outcomes represented:**

- unknown barcode
- duplicate scan for already Dispatched parcel
- Prepared parcel ready for dispatch
- other parcel state
- dispatch success
- dispatch failure

**Eligibility currently enforced by UI:**

- parcel state = Prepared
- assigned shipper exists and is active
- tracking ID exists

**UI rule:** Barcode input remains primary. Camera scanning is not part of this contract.

### 3.6 Bulk Dispatch

**Owner:** `src/components/BulkDispatchWorkspace.tsx`

**Requirements represented by current UI:**

- scan/resolve multiple parcels
- only Prepared parcels
- active assigned shipper
- existing tracking ID
- prevent duplicate parcel in batch
- per-parcel idempotency key
- batch dispatch
- per-parcel success/failure result
- failed items remain queued for safe retry

**Command layer:**

- `dispatchParcelsBulk`

**UI rule:** Preserve per-parcel results. Do not replace with an all-or-nothing visual model.

### 3.7 Delivery / NDR

**Owner:** `src/components/DeliveryOutcomeWorkspace.tsx`

**Current outcomes:**

From In Transit:

- Delivered
- NDR
- Lost
- Damaged

From NDR:

- Delivered
- Retry NDR

Retry NDR returns the parcel to In Transit through the existing command.

**Commands:**

- `record_delivery_outcome`
- `retry_ndr_parcel`

**Current parcel state handling:**

- In Transit = outcome selection available
- NDR = Delivered or Retry NDR
- terminal states = no further delivery outcome

**Terminal states represented by UI:**

- Delivered
- RTO
- Lost
- Damaged
- Cancelled

**UI rule:** Do not introduce `Out for Delivery` unless the authoritative application contract contains it.

### 3.8 RTO

**Owner:** `src/components/RtoScanWorkspace.tsx`

**Current eligibility:**

- In Transit
- NDR

**Command:**

- `process_rto`

**Important rule:**

- stored shipper is resolved automatically
- operator does not select a historical shipper

**Bulk RTO:**

`src/components/BulkRtoWorkspace.tsx`

- resolve multiple barcodes
- eligible states are In Transit/NDR
- process each parcel independently
- display success/failure counts

**UI rule:** Preserve per-parcel processing and stored-shipper behaviour.

### 3.9 COD & Finance

**Owner:** `src/components/CodFinanceWorkspace.tsx`

**Props:**

- `accessToken: string`
- `isAdmin: boolean`

**Current workflow:**

1. resolve order
2. create COD obligation
3. allocate obligation to parcel
4. record receipt
5. show receipt state/amounts
6. Admin resolves exceptions
7. Admin can view reconciliation

**Commands/RPCs used by current component include:**

- `create_cod_obligation`
- `allocate_cod_obligation_to_parcel`
- `record_cod_receipt`
- `resolve_cod_exception`
- `get_cod_financial_reconciliation`

**Current data shown:**

- original amount
- expected COD
- parcel count
- expected amount
- received amount
- receipt state
- variance
- outstanding
- effective amount
- reconciliation state

**Admin-only behaviour:**

- exception resolution
- reconciliation view

**UI rule:** No new financial calculations may be introduced merely for visual design.

### 3.10 Invoices

**Owner:** `src/components/InvoicePrintWorkspace.tsx`

**Current source:**

- `invoice_records`
- immutable `source_snapshot`
- template version
- generated timestamp
- order number

**Current actions:**

- select individual invoices
- select all
- download individual PDF
- download selected batch PDF
- print individual
- print selected batch
- refresh

**Print recording:**

- `record_invoice_print`
- modes: `individual` and `batch`

**Current print/download behaviour:**

- PDF is generated client-side from the stored invoice snapshot
- print uses a hidden iframe
- filename is derived from order number for individual PDFs
- batch filename is derived from first/last order numbers

**UI rule:** Do not replace the validated print/download path while redesigning presentation.

### 3.11 Reports

**Owner:** `src/components/ReportWorkspace.tsx`

**Current report sources defined in UI:**

- report_kpi_orders
- report_kpi_parcels
- report_kpi_delivery_outcomes
- report_kpi_financial
- report_kpi_imports
- report_orders
- report_parcel_delivery
- report_customer_activity
- report_cod_financial_reconciliation
- report_historical_import_reconciliation
- report_reconciliation_exceptions

**Current date presets:**

- All dates
- Today
- Yesterday
- Last 7 days
- Last 30 days
- Custom

**Current actions:**

- refresh
- filter
- Excel export

**Important existing behaviour:**

- first 25 rows displayed in each report table
- export includes the complete filtered dataset
- reports without authoritative date columns are not date-filtered

**UI rule:** Use existing report data only. Do not add trend percentages or new KPI calculations to support a mockup.

### 3.12 Admin

**Owner:** `src/components/AdminUserControls.tsx`

**Access:**

- active admin profile only

**Current functions:**

- load application profiles
- link existing Auth user ID to application profile
- assign Sales / Operations / Admin role
- activate/deactivate application profile

**Commands/RPCs:**

- `create_profile`
- `set_profile_active`

**UI rule:** Preserve admin-only gating and do not introduce Auth identity deletion or password-management functionality unless separately verified/scoped.

## 4. Shared UI state requirements

The modernization must preserve and improve presentation for:

- loading
- success
- error
- empty
- validation
- permission denied
- disabled/busy controls
- unknown barcode
- duplicate scan
- wrong state
- terminal state
- network/request timeout
- batch partial success/failure

Scan result announcements should be suitable for `aria-live` in the accessibility phase.

## 5. Responsive design contract

Target viewports:

- 390 × 844
- 430 × 932
- 768 × 1024
- 1280+

Mobile and desktop are intentionally different layouts but share the same design system.

Approved visual direction:

- **A — Clean Modern SaaS** as global foundation
- **B — Modern Operations** as primary operational language
- **C — Modern Logistics Command Center** selectively for scan/field operational surfaces

The visual direction is presentation-only and must not change business contracts.

## 6. Contract protection

The following are outside UI scope unless a separately approved task is created:

- database schema
- migrations
- DB reset/truncate/seed/restore
- RLS/policies
- stored functions/RPC definitions
- command semantics
- state machines/invariants
- authentication semantics
- authorization semantics
- API contract changes
- financial calculations
- new notification infrastructure
- camera barcode scanning
- language/RTL system
- offline synchronization

If a UI requirement cannot be fulfilled using the existing contract, record the gap instead of modifying the contract under a UI task.

## 7. Items requiring repository verification before implementation

The following are identified for the next contract/protection gates:

1. Exact authoritative lifecycle/parcel/COD state definitions in backend/database source.
2. Complete route/workspace inventory beyond the top-level `App.tsx` navigation.
3. Dedicated parcel list/detail UI coverage, if any.
4. Exact permission mapping for every navigation item.
5. Existing E2E/UAT selectors and terminology/glossary dependencies.
6. Existing CI/workflow files that can enforce the protected-path guard.
7. Main tracker T232–T241 evidence reconciliation.
8. Sensitive tracker sheet/credential check.

These are not to be guessed.

## 8. UI-002 completion criterion

UI-002 is complete when:

- this inventory is committed to the repository;
- each screen/workspace has a documented route/owner/props/data contract;
- command/API/RPC dependencies are recorded;
- roles and permissions are recorded;
- UI states and functional constraints are recorded;
- unresolved items are explicitly marked for verification;
- no application or database code was changed.

**No UI visual implementation is included in UI-002.**
