# P14-T213 — Query-Plan Review

## Objective
Review representative operational query plans against the locked PostgreSQL schema and verify that the authoritative indexes required by those access paths exist.

## Evidence
`supabase/tests/database/124_query_plan_review.sql`

The test is rollback-scoped and runs against the CI/local database with 5,000 synthetic customers, orders and parcels. It runs `ANALYZE` and captures `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for selective indexed lookups plus representative Orders and parcel reporting queries.

## Reviewed access paths
- `orders.customer_id` lookup
- `parcels.tracking_id` lookup
- Orders date/lifecycle reporting filter
- Parcel state reporting join
- Supporting index inventory for customer/date/lifecycle/order/state/tracking/delivery-outcome access

## Scope limitation
This is a deterministic CI/local query-plan characterization. It does not claim production query-plan certification, production workload capacity, Cloudflare latency, Supabase control-plane performance, or multi-client stress behavior.
