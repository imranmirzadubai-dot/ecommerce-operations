# P3-T074 Completion

## Task
Write positive/negative RLS tests.

## Result
PASS — positive and negative structural RLS tests cover the 17 application tables, SELECT policy coverage, and denial of direct browser writes.

## Positive checks
- All 17 application tables have RLS enabled.
- All application tables have SELECT policy coverage.
- Authenticated users retain approved SELECT access to orders.
- Admin-only financial-adjustment policy exists.
- Profile self-read policy exists.

## Negative checks
- No INSERT/UPDATE/DELETE RLS policies exist on application tables.
- Anonymous SELECT on orders is denied at the grant layer.
- Authenticated INSERT/UPDATE/DELETE on orders are denied at the grant layer.

## Test
`supabase/tests/database/025_rls_positive_negative.sql`

## Verification
Direct staging catalog and privilege checks passed. The SQL test is written for the repository's pgTAP-capable test environment; no pgTAP execution is claimed for staging where the runner is unavailable.

## Completion date
2026-09-12
