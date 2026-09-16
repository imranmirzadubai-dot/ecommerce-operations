# Staging vs Clean-Main Schema Diff — 2026-09-17

## Baselines

- Clean-main baseline: GitHub Actions run `35137155690`, fresh local Supabase reset from the reconciliation branch, schema artifact `clean_main_public_schema.sql`.
- Staging: live Supabase project `mijbpvgxrxjaalimyqgm`, exported from PostgreSQL catalogs with definitions for tables/columns/defaults/nullability, constraints, indexes, RLS, policies, triggers and functions.
- A literal remote `pg_dump` of staging was not possible from the available execution environment because the database password/connection credential is not exposed and local `pg_dump`/`migra` binaries are unavailable. The staging catalog export is therefore the machine-readable definition-level substitute, not a claim of a literal `pg_dump`.

## Object-level diff

### Tables

Clean-main: **20**  
Staging: **18**

Missing from staging:

- `public.invoice_print_events`
- `public.invoice_template_versions`

No staging-only application tables were found.

### Functions

Clean-main: **35**  
Staging: **15**

Missing from staging:

- `allocate_parcel_item`
- `allocate_parcel_items`
- `assert_order_item_allocation_invariant`
- `assert_order_item_physical_outcome_invariant`
- `capture_invoice_historical_snapshot`
- `correct_parcel_allocation`
- `create_parcel`
- `create_profile`
- `normalize_uae_phone`
- `prevent_confirmed_order_item_change`
- `prevent_confirmed_original_amount_change`
- `prevent_invoice_print_event_mutation`
- `prevent_invoice_record_historical_snapshot_mutation`
- `prevent_invoice_template_version_mutation`
- `record_invoice_print`
- `resolve_or_create_customer`
- `set_profile_active`
- `update_order`
- `validate_parcel_item_allocation`
- `validate_parcel_state_allocation`

No staging-only public functions were found.

### RLS policies

Clean-main: **20**  
Staging: **17**

Missing from staging:

- `invoice_print_events_authenticated_select`
- `invoice_template_versions_authenticated_select`
- `profiles_admin_select`

### Non-constraint indexes

Clean-main: **38**  
Staging: **34**

Missing from staging:

- `idx_invoice_print_events_invoice_record_id`
- `idx_invoice_print_events_order_id`
- `idx_invoice_print_events_printed_at`
- `idx_invoice_print_events_printed_by`
- `idx_invoice_template_versions_supersedes`

Staging-only:

- `invoice_records_invoice_number_unique`

The staging-only invoice index is associated with a duplicate logical uniqueness constraint already identified in the audit.

## Confirmed definition-level differences

### `invoice_records`

Clean-main contains an additional required column:

```sql
source_snapshot jsonb NOT NULL
```

with:

```sql
CHECK (jsonb_typeof(source_snapshot) = 'object')
```

Clean-main also has the `invoice_records_template_version_fkey` relationship into template-version lineage. Staging does not have the current template-version lineage objects.

### `parcel_items`

Clean-main contains the composite uniqueness boundary:

```text
parcel_items_parcel_id_order_item_id_allocation_state_key
```

Staging does not.

### `orders`

Staging contains duplicate logical checks:

- `orders_currency_code_check`
- `orders_t055_currency_aed_check`

both enforcing the same AED condition.

and:

- `orders_original_amount_check`
- `orders_t055_original_amount_nonnegative_check`

both enforcing the same non-negative amount condition.

These are corrective/destructive candidates, not automatically safe drops.

### `invoice_records`

Staging contains duplicate logical uniqueness constraints:

- `invoice_records_invoice_number_key`
- `invoice_records_invoice_number_unique`

Both enforce `UNIQUE (invoice_number)`.

This is another corrective/destructive candidate.

## Classification

### Safe/additive candidates

Examples:

- `invoice_template_versions`
- `invoice_print_events`
- `update_order`
- current-main command/helper functions missing from staging
- missing current-main indexes/policies

These still require dependency and data-compatibility review before deployment.

### Corrective/destructive candidates

- duplicate `orders` checks
- duplicate `invoice_records` uniqueness constraints
- any other definition-level duplicates revealed by the remaining full comparison

No destructive change should be applied merely because clean-main differs from staging.

### Unexplained

The historical staging migration IDs do not provide provenance for all staging objects/functions. Any staging-only object or behavior without a verified source migration remains **unexplained/legacy** until provenance is established.

## Current conclusion

The clean-main baseline confirms that staging is materially behind and divergent from the current repository schema.

The earlier framing that staging was essentially **"already implemented and only needed lineage reconciliation"** is corrected by this evidence.

The next migration work must be based on this definition-level diff, followed by dependency/data-safety review and a forward migration candidate. No production migration is justified by this diff alone.
