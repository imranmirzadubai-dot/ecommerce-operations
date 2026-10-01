# UI-MP 1.2 — Approved Visual Baseline Lock

**Status:** LOCKED  
**Date:** 2026-10-01  
**Baseline:** Main merge commit `12b19b17cdf5731af0c97bcfdd82c515a498750b`

## Authority

The Business Owner explicitly approved the supplied 12-screen mobile UI mockup grid in the project conversation on 2026-10-01 and instructed the team to lock it and continue with design.

This visual baseline supersedes the earlier generic wireframe presentation as the primary visual reference for production UI implementation.

## Approved screen set

1. Dashboard / Home
2. Orders List
3. Order Details
4. Dispatch / Scan
5. Delivery / NDR
6. COD / Finance
7. Invoices
8. Reports
9. Customers
10. Parcels
11. Mobile Navigation Menu
12. Profile / Settings

## Visual rules

- Mobile-first operational application.
- Light, clean surfaces with compact information density.
- Blue is the primary action/interaction color.
- Green communicates ready/success/collected/delivered states.
- Orange communicates pending/in-transit/attention states.
- Red communicates exception/NDR/problem states.
- Purple is used selectively for invoice/finance actions.
- Rounded cards and controls with restrained elevation.
- Large touch targets for operational actions.
- Bottom navigation for primary mobile destinations.
- Hamburger/menu surface for the full navigation set.
- Search, filter and status-chip patterns follow the supplied reference.
- Dispatch/Scan is scan-first and operationally focused.
- Tables/lists must remain readable and compact.
- Do not replace this design with the earlier generic SaaS wireframe.
- Do not introduce decorative KPI/trend data that is not backed by the existing application contract.

## Responsive intent

- 390/430px: the supplied mobile patterns are the visual authority.
- 768px: adapt the same hierarchy into tablet space without changing workflow semantics.
- 1280px+: use the same visual language in a wider operational workspace.

## Functional boundary

This lock changes presentation/design only. It does not authorize changes to:
- authentication/session behavior
- roles/permissions
- API contracts
- commands/RPCs
- order/parcel/COD/invoice/report business rules
- database schema, migrations, RLS, constraints, triggers or functions

## Implementation rule

For each screen:
**reference → contract check → UI implementation → CI → preview → visual verification → merge**

If a requested visual change conflicts with an existing business/UI contract, stop at the conflict and document it rather than inventing behavior.

## Previous baseline clarification

The earlier SVG wireframes remain historical structural artifacts. They are not the primary visual reference for the polished production UI after this lock.
