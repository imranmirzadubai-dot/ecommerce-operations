# UI-MP 1.2 — Production Visual Design Specification

**Authority:** `UI-MP-1.2_APPROVED_VISUAL_BASELINE_LOCK.md`  
**Reference:** Business Owner supplied 12-screen mobile mockup grid, approved 2026-10-01.

## 1. Global visual system

### Structure
- iPhone/mobile operational layout is the primary visual reference.
- Top bar: compact title, hamburger/back/search/notification controls as appropriate.
- Content: stacked cards and dense operational lists.
- Bottom navigation: Home, Orders, Scan, Reports, More.
- Full navigation: slide-out/menu surface.
- Primary actions use prominent filled buttons.
- Secondary actions use light/outlined controls.
- Operational status is always represented with compact status chips.

### Typography
- Strong, compact page titles.
- Medium-weight section headings.
- Small supporting metadata.
- Numeric values are emphasized only when the underlying application contract supplies them.

### Surfaces
- Light neutral application background.
- White content cards.
- Moderate corner radius.
- Very restrained shadow/elevation.
- No heavy gradients or decorative background effects.

### Status semantics
- Ready / success / collected / delivered → green.
- Pending / in transit / attention → orange.
- NDR / exception / failure → red.
- Primary action / selected navigation → blue.
- Finance / invoice emphasis → selective purple.

## 2. Screen specifications

### Dashboard / Home
- Greeting and date context.
- Operational summary cards only where backed by live application data.
- Needs Attention list.
- Quick Actions.
- Preserve the visual hierarchy of the approved reference.
- Never invent operational counts or trends.

### Orders List
- Search bar with filter control.
- Lifecycle/state filter chips.
- Compact order cards.
- Reference, customer, contact/metadata, value, item count, parcel and status.
- Overflow action where supported.
- Mobile bottom navigation.

### Order Details
- Order reference and current state.
- Tabs: Overview / Items / Timeline / Notes where supported.
- Customer identity/contact.
- Parcel state and tracking context.
- Item list.
- Totals.
- Existing actions only.

### Dispatch / Scan
- Scan tab as the primary operational surface.
- Large scan target/instruction.
- Manual barcode entry fallback.
- Last Scan result.
- Today's progress only if backed by existing data.
- Recent scans only if backed by existing data.
- Large scan/dispatch action targets.
- No camera feature unless separately implemented and contracted.

### Delivery / NDR
- State tabs.
- Search/lookup.
- Parcel cards with order/customer/status.
- Delivery outcome controls only for documented transitions.
- NDR retry only where the contract permits it.

### COD / Finance
- COD summary using authoritative reconciliation data.
- Collected / exceptions / success metrics only when available.
- Pending / exceptions / collections navigation.
- Obligation/receipt/exception workflows remain unchanged.

### Invoices
- To Print / Printed / Batch grouping.
- Individual invoice rows.
- Batch print action.
- Existing PDF generation and print recording semantics preserved.

### Reports
- Date range/preset.
- Report source/filter controls.
- Contract-backed result data.
- Excel export.
- Charts only where the current report source supplies the required dataset; otherwise use the result/table presentation.

### Customers
- Search by customer name/phone.
- Customer identity and contact information.
- Order count/history where already supported.
- Customer history access.

### Parcels
- Parcel search.
- State filter chips.
- Parcel cards showing tracking/order/status.
- Existing allocation/dispatch/delivery/RTO semantics only.

### Mobile Navigation Menu
- Account header.
- Primary workspace links.
- Settings.
- Logout.
- Role-based visibility must remain unchanged.

### Profile / Settings
- Current user/profile identity.
- Existing profile/settings options only.
- Appearance/language only if already supported.
- Logout.
- No invented account-management capabilities.

## 3. Responsive translation

### 390/430
Follow the supplied mobile mockup directly.

### 768
- Preserve mobile hierarchy.
- Increase usable width.
- Allow dense tables to scroll when necessary.
- Keep operational actions reachable without reducing touch targets.

### 1280+
- Translate the same cards/list hierarchy into a persistent navigation + operational workspace.
- Do not turn the application into a generic analytics dashboard.

## 4. Implementation acceptance

A screen is visually accepted only when:
1. It matches the approved visual language.
2. Every displayed data point is contract-backed.
3. Existing workflows and permissions remain unchanged.
4. 390/430 behavior is usable.
5. 768 behavior is usable.
6. 1280+ behavior is usable.
7. Loading, empty, error and disabled states are represented where applicable.
8. CI passes.
9. Preview deployment succeeds.
10. Visual verification is performed before merge when browser access is available.
