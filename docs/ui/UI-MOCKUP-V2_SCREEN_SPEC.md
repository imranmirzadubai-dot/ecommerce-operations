# UI-MP-1.2 — Mockup v2 Screen Specification

**Purpose:** Contract-accurate responsive design blueprint before production screen implementation.

**Design lock:** A + B hybrid, with selective C only for scan/field operational surfaces.

## Global layout

### Desktop 1280+
- Persistent left navigation.
- Compact top utility bar.
- Main content max-width 1280px.
- Clear page heading + contextual actions.
- Dense operational tables where data requires it.
- No decorative dashboard-only metrics unless backed by existing data.

### Tablet 768
- Collapsible navigation.
- One- or two-column cards depending on content.
- Tables remain horizontally scrollable where necessary.
- Primary actions remain reachable without precision tapping.

### Mobile 390 / 430
- Compact top bar.
- Navigation becomes a bottom/compact menu presentation.
- One primary task per screen section.
- Tables transform into stacked records/cards when that preserves all required fields.
- Scan and operational actions use large touch targets.
- Filters use a compact sheet/popover pattern rather than permanently consuming vertical space.

## Screen 01 — Dashboard / Home

**Visual:** A+B.

Structure:
1. Page heading.
2. Authentication/access state.
3. Quick operational entry for Create Draft Order.
4. Existing foundation/status information.
5. Existing workspace status indicators.

Do not invent KPI values, trends, notification counts or financial totals.

Mobile:
- Create Draft Order becomes the primary task.
- Form fields stack.
- Item rows remain editable without horizontal scrolling.

## Screen 02 — Customers

**Visual:** A+B.

Structure:
- Phone lookup at top.
- Customer identity result.
- Customer history.
- Clear empty/not-found state.

Mobile:
- Phone lookup and result are sequential.
- History records become cards.

## Screen 03 — Orders

**Visual:** A+B.

Structure:
- Page heading + refresh/export.
- Search.
- Lifecycle / parcel / COD filters.
- Date views.
- Results table.
- Pagination.
- Order detail/editor and timeline.

Mobile:
- Search remains prominent.
- Filters collapse into a filter control.
- Order records become cards.
- Draft actions remain visible only where contract permits.

## Screen 04 — Parcels / allocation

**Visual:** A+B.

Use only functionality already exposed by the existing contract.

Structure:
- Parcel context.
- Allocation/split/correction controls where currently available.
- State and tracking information.
- Explicit validation/error feedback.

Do not create a new unsupported parcel workflow merely to populate navigation.

## Screen 05 — Dispatch / Scan

**Visual:** B + selective C.

Structure:
- Large scan/input control.
- Immediate parcel result.
- State, shipper and tracking context.
- Primary dispatch action.
- Strong success/error/duplicate/unknown feedback.

Mobile:
- Scan field receives immediate focus where appropriate.
- 44px+ controls.
- Result and action remain above the fold.

Camera scanning is not added unless separately scoped.

## Screen 06 — Bulk Dispatch

**Visual:** B.

Structure:
- Batch input/queue.
- Eligibility summary.
- Per-parcel result list.
- Partial-success and failure states.
- Retry failed items where existing behaviour supports it.

Never collapse mixed batch outcomes into a single success indicator.

## Screen 07 — Delivery / NDR

**Visual:** B + selective C.

Structure:
- Parcel lookup/scan.
- Current state.
- Outcome controls.
- Required result feedback.
- NDR retry path.

Only documented transitions are presented.

## Screen 08 — RTO

**Visual:** B + selective C.

Structure:
- Scan-first lookup.
- Eligibility state.
- Resolved shipper/tracking context.
- RTO action.
- Explicit invalid-state feedback.

Do not require historical shipper selection.

## Screen 09 — COD & Finance

**Visual:** A+B.

Structure:
- Order lookup.
- COD obligation context.
- Receipt entry.
- Reconciliation/exception state.
- Admin-only resolution controls where authorized.

Financial values come only from authoritative existing data/commands.

## Screen 10 — Invoices

**Visual:** A+B.

Structure:
- Invoice list.
- Selection.
- Individual PDF download.
- Batch PDF download.
- Individual print.
- Batch print.

Mobile:
- Selection remains simple.
- Download/print actions use a compact action bar.

Existing snapshot/template/print-recording semantics remain unchanged.

## Screen 11 — Reports

**Visual:** A+B.

Structure:
- Report source selection.
- Date/filter controls.
- Refresh.
- Results.
- Excel export.

The interface must clearly distinguish displayed first-25 rows from the complete export dataset.

No invented charts/KPIs.

## Screen 12 — Admin Users

**Visual:** A.

Structure:
- Admin-only access.
- Profile list.
- Auth-user linking.
- Role assignment.
- Active/inactive controls.

No change to authorization semantics.

## Shared state language

Every screen must define:
- loading
- empty
- validation
- success
- error
- disabled/busy
- permission denied
- terminal state
- partial batch result where applicable

Operational result messages use accessible live-region treatment.

## Mockup acceptance gates

Before production screen implementation:
1. Confirm every visible field/action maps to the UI-002 contract.
2. Confirm no unsupported data is introduced.
3. Confirm mobile 390/430 layouts.
4. Confirm tablet 768 layout.
5. Confirm desktop 1280+ layout.
6. Confirm scan/field surfaces use selective C treatment only.
7. Record Business Owner design approval in the UI tracker.

**Status: DESIGN SPEC READY — production screen implementation remains gated by mockup approval.**
