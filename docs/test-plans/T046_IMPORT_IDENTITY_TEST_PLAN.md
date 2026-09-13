# T046 Historical Import Identity Test Plan

## 1. Objective

Verify the historical import identity contract before Phase 3 implementation. Tests are expressed as required properties; they do not imply that the current foundation already implements every property.

## 2. Scope

Covers batch identity, source identity, physical row identity, raw/normalized evidence, duplicate/conflict classification, replay/re-import behavior, domain identifier protection, auditability, authorization, and rollback evidence.

## 3. Test matrix

| ID | Property | Expected result | Current status |
|---|---|---|---|
| T046-01 | Batch UUID identity | Every batch has a unique immutable internal UUID | Contract |
| T046-02 | Filename non-uniqueness | Same source filename may exist in multiple batches without collision | Contract |
| T046-03 | Batch source namespace | `source_system` identifies source namespace but does not alone identify a batch | Contract |
| T046-04 | Row identity | `(batch_id, source_row_number)` uniquely identifies a staged physical row | Implemented constraint |
| T046-05 | Positive row number | `source_row_number > 0` | Implemented constraint |
| T046-06 | Row-number immutability | Existing row position cannot be rewritten as part of reordering/re-import | Required implementation behavior |
| T046-07 | Source-ID preservation | `source_record_id` preserves source identity without destructive normalization | Required implementation behavior |
| T046-08 | Missing source ID | Row remains traceable through batch and row position | Required implementation behavior |
| T046-09 | Raw evidence preservation | `raw_data` remains source representation | Required implementation behavior |
| T046-10 | Normalized separation | Canonical comparison values are stored separately from preserved raw identity | Required implementation behavior |
| T046-11 | Same identity/same payload | Replay is classified idempotently and does not create a duplicate domain record | Required implementation behavior |
| T046-12 | Same identity/different payload | Conflict is rejected/quarantined for explicit review | Required implementation behavior |
| T046-13 | Similar fields/different identity | Similar business fields alone do not establish identity | Required implementation behavior |
| T046-14 | Re-import immutability | Prior completed batch remains unchanged when corrected source is imported | Required implementation behavior |
| T046-15 | Domain UUID authority | Existing mapped domain UUID remains authoritative | Required implementation behavior |
| T046-16 | Sequence protection | Import never assigns/rewrites sequence identifiers using client values or `MAX()+1` | Required implementation behavior |
| T046-17 | Mapping lineage | Source system, batch, source row/ID, target entity, target UUID, classification and actor remain reconstructable | Phase 3 schema/command |
| T046-18 | Admin-only import | Sales/Operations cannot execute import command successfully | Phase 3 security test |
| T046-19 | Anonymous denial | `anon` cannot execute import command or write import staging | Phase 3 security test |
| T046-20 | Helper bypass denial | Lower-level helper cannot bypass Admin-only import authorization | Phase 3 security test |
| T046-21 | Audit evidence | Import actions produce appropriate audit/event evidence transactionally | Phase 3 implementation |
| T046-22 | Failed-batch evidence | Failed/partial batch remains identifiable and auditable | Phase 3 implementation |
| T046-23 | Rollback evidence | Rollback reverses domain effects while preserving import evidence and recording the reversal | Phase 3 implementation |
| T046-24 | Source-content fingerprint | Identical file content can be deterministically recognized for replay/no-op handling | Phase 3 schema/command |

## 4. Catalog verification baseline

Before Phase 3 implementation, inspect the database catalog for:

- primary key on `import_batches.id`;
- primary key on `import_rows.id`;
- foreign key `import_rows.batch_id -> import_batches.id`;
- uniqueness of `(batch_id, source_row_number)`;
- positive check on `source_row_number`;
- nullability of `source_record_id`;
- availability of `raw_data` and `normalized_data`;
- import-batch status constraints;
- absence of unintended direct application-role write grants.

## 5. Negative tests

The following must fail closed in the implemented import path:

- anonymous import execution;
- non-Admin import execution;
- direct browser mutation of protected import evidence;
- duplicate source identity with materially different payload;
- attempts to overwrite an accepted historical batch;
- attempts to renumber imported business identifiers;
- attempts to use source identifiers as arbitrary internal UUIDs.

## 6. Acceptance criteria

T046 is complete when the architecture contract and this test plan are committed on the T046 branch, the current schema baseline is documented accurately, implementation gaps are explicitly assigned to Phase 3, and no live/staging business data has been modified as part of formalization.
