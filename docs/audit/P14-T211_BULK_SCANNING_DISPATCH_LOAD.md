# P14-T211 — Bulk Scanning / Dispatch Load Testing

## Objective
Characterize the repository database behavior for representative bulk parcel scanning and dispatch operations.

## Workload
- 5,000 synthetic confirmed orders
- 5,000 synthetic parcels
- 1,000 exact barcode lookups representing a bulk scan batch
- Atomic state transition of 5,000 parcels from `Prepared` to `Dispatched`
- Dispatch timestamp integrity verification

## Evidence
`supabase/tests/database/123_bulk_scanning_dispatch_load.sql`

The test is rollback-scoped and runs entirely against the CI/local database. The dataset is removed by `ROLLBACK`.

## Performance contract
The test records a characterization budget of less than 5 seconds for the bulk scan lookup and the 5,000-row dispatch transition. This is a deterministic CI/local benchmark, not a production SLO or capacity certification.

## Scope limitation
This milestone does not claim multi-client concurrent scanning, network/browser latency, Cloudflare capacity, Supabase control-plane capacity, or production throughput. Those require a separately authorized deployed-environment test with appropriate test data and environment gates.
