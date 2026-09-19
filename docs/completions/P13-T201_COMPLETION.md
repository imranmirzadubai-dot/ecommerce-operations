# P13-T201 — Operational Reports

## Scope
Implemented the three operational report projections defined by the locked Phase 13 report specifications:

- RPT-01 — Order Summary / Orders Report
- RPT-02 — Parcel & Delivery Operations Report
- RPT-03 — Customer Activity Report

## Implementation
- `public.report_orders`: one row per order with customer reference, city, immutable original amount, lifecycle state, parcel count and physical outcome counts.
- `public.report_parcel_delivery`: one row per parcel with order, shipper, tracking, dispatch and latest delivery outcome information; COD receipt amount is exposed where recorded.
- `public.report_customer_activity`: one row per customer with canonical normalized phone, order counts, first/latest order dates, original order amount total and current open order count.

All views are read-only projections using security-invoker semantics. Anonymous SELECT is revoked and authenticated SELECT is granted.

## Verification
- Migration applied successfully to staging (`ecommerce-operations-staging`).
- All three objects verified as PostgreSQL views in staging.
- Staging currently contains no business rows, so report row counts are zero.
- Database contract tests are included in `supabase/tests/database/119_operational_report_views.sql`.

## Boundary
No production business data or production schema was changed by this milestone implementation. Production deployment remains subject to the project's formal deployment gates.
