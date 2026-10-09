# Production runtime migration reconciliation — 2026-10-09

## Purpose

This record documents forward-only runtime contract repairs applied to production after the live application reported missing PostgREST RPC functions. It does **not** authorize resetting production, replaying historical migrations, or changing existing business data.

## Safety status

- No production table reset was performed.
- No test orders, parcels, COD receipts, invoice records, or financial adjustments were created.
- Restored functions were checked for expected identity arguments and authenticated/anonymous execution privileges where recorded.
- A PostgREST schema reload was requested after restoring functions.
- The production migration ledger still requires formal reconciliation against the repository before a clean CLI migration plan can be claimed.

## Runtime repairs recorded in production

| Production ledger version | Ledger name | Repository source migration |
|---|---|---|
| 20261009040709 | runtime_restore_cancel_parcel | 20260911160000_cancel_parcel_contract.sql |
| 20261009040714 | runtime_restore_create_parcel | 20260913140000_parcel_creation.sql |
| 20261009040718 | runtime_restore_allocate_parcel_item | 20260913150000_parcel_allocation_command.sql |
| 20261009040722 | runtime_restore_split_parcel_allocation | 20260913160000_split_parcel_allocation.sql |
| 20261009040730 | runtime_restore_correct_parcel_allocation | 20260913160100_correct_parcel_allocation.sql |
| 20261009040741 | runtime_restore_create_cod_obligation | 20260918080000_order_cod_obligation.sql |
| 20261009040751 | runtime_restore_create_cod_obligation (duplicate) | 20260918080000_order_cod_obligation.sql |
| 20261009040758 | runtime_restore_allocate_cod_obligation | 20260918090000_parcel_cod_allocation.sql |
| 20261009040802 | runtime_restore_cod_obligation_grants | 20260918170000_cod_obligation_command_access_hardening.sql |
| 20261009040806 | runtime_restore_cod_receipt_contract | 20260929070000_p15_t236_cod_receipt_final_qualifiers.sql |
| 20261009040814 | runtime_restore_cod_receipt_variance_state | 20260918220000_cod_receipt_variance_exception.sql |
| 20261009040818 | runtime_restore_cod_exception_resolution | 20260929080000_p15_t236_cod_exception_receipt_ambiguity_hardening.sql |
| 20261009040822 | runtime_restore_cod_financial_reconciliation | 20260918290000_cod_financial_reconciliation.sql |
| 20261009040828 | runtime_restore_invoice_template_lineage | 20260914010000_invoice_template_version_lineage.sql |
| 20261009040832 | runtime_restore_invoice_print_events | 20260914020000_invoice_print_event_tracking.sql |
| 20261009040847 | runtime_restore_assign_parcel_shipper | 20260915090000_shipper_assignment.sql |
| 20261009040852 | runtime_restore_tracking_id_validation | 20260915100000_tracking_id_validation.sql |
| 20261009040856 | runtime_restore_dispatch_parcel | 20260916090000_dispatch_parcel.sql |
| 20261009040859 | runtime_restore_delivery_outcome | 20260916093000_record_delivery_outcome.sql |
| 20261009040904 | runtime_restore_retry_ndr | 20260916120000_retry_ndr_parcel.sql |
| 20261009040908 | runtime_restore_process_rto | 20260918145000_process_rto_stored_shipper.sql |
| 20261009041000 | runtime_restore_financial_adjustment_command | 20260918250000_financial_adjustment_command.sql |

## Required next actions

1. Compare the full remote migration ledger with every local migration filename and content.
2. Confirm each runtime repair is semantically equivalent to its listed source migration; filename mapping alone is not proof.
3. Determine the least-risky supported migration-repair plan for migrations already represented in production. Do not run repair until the plan has been reviewed against the actual remote and local histories.
4. Run read-only schema/function/privilege checks and CI tests.
5. Verify workflows using disposable fixtures in a transaction and roll them back, or use a dedicated non-production project. Do not create live business records for smoke tests.
6. Keep Worker deployment separate from database reconciliation; deploy it only if a source change requires it.

## Important limitation

This is an audit record, not a migration repair. The repository and production migration history must not be described as fully reconciled until the local/remote version comparison and a non-destructive migration-plan verification are complete.
