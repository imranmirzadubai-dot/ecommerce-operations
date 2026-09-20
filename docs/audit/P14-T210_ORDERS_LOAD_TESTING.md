# P14-T210 — Orders Load Testing

## Objective

Characterize the Orders data access path under a deterministic synthetic workload before environment-level performance testing.

## Workload

- 5,000 synthetic customers
- 5,000 synthetic orders
- 5,000 synthetic order items
- Orders distributed across the latest 30 calendar days
- Lifecycle states distributed across Draft, Confirmed, Active/Completed-equivalent reporting coverage, and Cancelled according to the existing schema

## Queries exercised

1. Orders workspace-style filtered listing joining orders to customers with date and lifecycle predicates.
2. Lifecycle summary grouped by lifecycle state and summing the immutable original order amount.
3. Customer activity aggregation joining customers and orders.

Each query is measured with `clock_timestamp()` and uses a deliberately broad 5-second per-query CI budget. The test also asserts that the expected synthetic row counts remain intact.

## Safety

The workload is fully rollback-scoped. It creates only deterministic test identities and synthetic rows inside one database transaction and ends with `rollback;`. It does not modify production business data.

## Scope limitation

This is a repository/local database load-characterization test. It is not a multi-client stress test, production capacity certification, or Cloudflare/Supabase control-plane benchmark. Those require an approved deployed test environment and controlled workload gates.

## Evidence

Test: `supabase/tests/database/122_orders_load_testing.sql`
