# Historical Import Identity Rules — T046

## 1. Purpose

This document formalizes identity, deduplication, replay, correction, and lineage rules for historical imports in the E-Commerce Operations MVP.

Historical import is an administrative operation. Import staging is evidence-bearing infrastructure, not an alternate business-data write path.

This is a Phase 2 architecture contract. It defines the required identity semantics without silently implementing Phase 3 schema changes or import commands.

## 2. Identity layers

Historical import has four distinct identity layers. They must not be conflated.

| Layer | Identity | Authority | Mutable? | Purpose |
|---|---|---|---|---|
| Import batch | `import_batches.id` UUID | Application/database | No | Identifies one ingestion attempt/version of source material |
| Source record | `import_rows.source_record_id` | Source system | No | Preserves the source system's record identity when supplied |
| Source position | `(batch_id, source_row_number)` | Import file/batch | No | Uniquely identifies a physical row position within one imported batch |
| Domain record | Domain table UUID / generated business identifier | E-Commerce Operations database | No | Identifies the resulting authoritative business record |

The internal domain UUID and generated business identifier are authoritative after a record is admitted to the domain model. Source identifiers remain lineage/reconciliation identifiers and must never replace internal identifiers.

## 3. Import-batch identity

`import_batches.id` is the authoritative identity of an import batch.

Rules:

1. Every import attempt receives a new immutable batch UUID.
2. A source filename is descriptive metadata, not a unique identity.
3. `source_system` identifies the originating system or feed namespace; it is not sufficient by itself to identify an import.
4. The same filename may legitimately occur in multiple imports.
5. A repeated file must not overwrite an earlier batch or historical evidence.
6. Re-imports, corrected source files, and intentionally repeated snapshots are separate batch identities and remain separately auditable.
7. Future implementation should persist a deterministic source-content/version fingerprint when idempotent file-level replay detection is required. The current foundation schema does not contain such a fingerprint column; this is a Phase 3 requirement.

## 4. Source-record identity

When the source provides a stable record identifier, it is preserved exactly in `import_rows.source_record_id`.

Rules:

1. Source identity is opaque: the importer must not reinterpret a source ID as an E-Commerce Operations ID.
2. Source IDs are compared within the source-system namespace and applicable import scope, not assumed globally unique across unrelated systems.
3. Whitespace, case, leading zeroes, punctuation, and other source-significant characters must not be silently changed in the preserved source identity. Any canonicalized comparison key belongs in normalized processing data, not in the preserved raw identity.
4. A missing source record ID does not make a row unidentifiable: `(batch_id, source_row_number)` remains the minimum row identity.
5. Source record IDs are immutable evidence. Corrections create new import evidence rather than rewriting a prior source identity.
6. The current schema does not enforce uniqueness of `source_record_id`; uniqueness requirements that depend on source-system semantics must be implemented explicitly in the later import schema/command work rather than assumed from the column's existence.

## 5. Row identity and ordering

`(batch_id, source_row_number)` is the authoritative physical-row identity for the current staging schema.

Rules:

1. `source_row_number` is one-based and must be positive.
2. A source row number is unique within its batch.
3. Row numbers are assigned from source-file position and must not be regenerated from imported business IDs.
4. A row's source position is immutable after staging.
5. Reordering a source file produces a new batch; it must not rewrite the row numbers of an existing batch.
6. Duplicate source rows in the same batch are separate physical rows until deduplication/conflict rules classify them.

## 6. Raw versus normalized identity

The importer must preserve source evidence separately from normalized processing values.

- `raw_data` is the preserved source representation and must not be rewritten to make it fit the target schema.
- `normalized_data` is derived processing data and may contain canonicalized values used for validation/matching.
- A normalization rule must never destroy the ability to reconstruct the original source identity.
- If a source field is both an identifier and a value requiring normalization for matching, retain the original identifier and store the normalized comparison representation separately.

## 7. Duplicate and conflict classification

For a stable source record identity, the importer must distinguish duplicates from conflicts.

| Condition | Required classification | Action |
|---|---|---|
| Same source identity, same source payload within the same logical import scope | Duplicate/idempotent replay | Do not create a second domain record |
| Same source identity, materially different source payload | Identity conflict | Reject/quarantine for explicit administrative review |
| Different source identity, same business-looking fields | Not an identity match | Do not deduplicate solely from approximate business-field equality |
| Missing source identity, same physical row repeated | Physical duplicate candidate | Resolve using batch/row evidence and explicit import rules |

A fuzzy match may be a review aid, but it must not silently establish identity for a historical transaction.

## 8. Re-import and idempotency

Import idempotency is distinct from command idempotency.

Command idempotency prevents one application command from applying twice. Import identity prevents the same source evidence from silently producing duplicate historical business records.

Required behavior:

1. A completed import batch is immutable evidence.
2. Retrying the same import operation must not mutate or erase the prior batch.
3. If source content is demonstrably identical to an already accepted import, the importer should classify it as a replay/no-op or explicitly link it to the prior batch according to the Phase 3 import command contract.
4. If source content differs, it is a new import version and requires normal validation/reconciliation.
5. A partial or failed batch remains evidence of the attempted import; it is not silently converted into a different batch.
6. Import completion must be based on reconciliation results, not merely successful file parsing.

## 9. Domain-identifier rules during import

Historical import must not violate the identifier/sequence contract.

1. Existing internal UUIDs are authoritative when a source record has already been mapped to a domain record.
2. Human-readable customer/order/parcel identifiers remain database-owned and immutable.
3. Import must not use `MAX(...) + 1`, client-generated sequence values, or sequence rewrites.
4. A source-provided order/customer/parcel number may be retained as source evidence, but it must not be blindly assigned to an internal identifier column unless the import contract explicitly establishes that it is the authoritative existing identifier.
5. Importing historical records must not renumber current records to make source numbering contiguous.
6. Sequence gaps caused by ordinary database sequence behavior remain valid and must not be repaired during import.

## 10. Mapping identity to domain records

A historical source record becomes a domain record only through an explicit, auditable mapping decision.

The mapping process must establish:

- source system;
- import batch;
- source record ID when available;
- source row number;
- target entity type;
- target internal UUID;
- match status and confidence/classification;
- actor/command responsible for the import decision;
- validation/reconciliation outcome.

The current staging schema does not yet contain all target mapping columns. These are implementation requirements for the later import command/schema milestones, not fields to infer or overload in the existing tables.

## 11. Corrections and historical evidence

Historical evidence is append-oriented.

- Never rewrite an accepted source row to conceal a correction.
- Never delete an earlier import merely because a corrected file was received.
- A corrected source file creates a new batch/version and records the relationship to the prior evidence in the future import model.
- Domain corrections must use the applicable domain command/adjustment/event rules.
- Audit evidence must identify the authorized actor responsible for the import or correction.

Rollback is a controlled administrative operation, not deletion of source evidence. A rollback must preserve the batch and explain which domain effects were reversed.

## 12. Security and authorization boundary

Historical import is Admin-only.

The import path must enforce:

1. authenticated identity;
2. active `admin` application role;
3. explicit function/command execution privilege;
4. transactional validation and invariant checks;
5. append-only import/audit evidence;
6. no anonymous execution;
7. no direct browser write path around the import command.

Raw source data may contain sensitive business information. Access and audit exposure must therefore follow the Admin-only import staging contract.

## 13. Current schema baseline and implementation gaps

The current foundation provides:

- `import_batches.id` as a UUID primary key;
- `source_system`, `source_file`, `initiated_by`, lifecycle status/timestamps, and reconciliation summary on the batch;
- `import_rows.id` as a UUID primary key;
- `batch_id` as the authoritative batch relationship;
- positive `source_row_number` with a unique `(batch_id, source_row_number)` constraint;
- optional `source_record_id`;
- preserved `raw_data` and optional `normalized_data`;
- row status and error fields.

The current foundation does **not** yet enforce:

- a source-content/version fingerprint for file-level replay detection;
- source-system-specific uniqueness semantics for `source_record_id`;
- an explicit persisted source-to-domain mapping identity;
- a formal duplicate/conflict resolution state model beyond the current row status/error fields.

These are deliberate Phase 3 implementation requirements. T046 formalizes the semantics without silently changing the live/staging database.

## 14. Required Phase 3 test properties

At minimum, implementation tests must prove:

1. every batch has immutable internal identity;
2. repeated filenames do not collide;
3. `(batch_id, source_row_number)` is unique and positive;
4. source IDs are preserved without destructive normalization;
5. missing source IDs remain traceable by batch and row position;
6. same-source-identity/same-payload replay is not duplicated;
7. same-source-identity/different-payload is rejected or quarantined;
8. approximate business-field matches do not silently merge records;
9. prior batches remain immutable evidence after re-import/correction;
10. internal business identifiers are never client-assigned or renumbered;
11. import commands are Admin-only and protected from anonymous/helper bypass;
12. rollback preserves import evidence and produces auditable reversal evidence.

## 15. T046 decision

**FORMALIZED — historical import identity rules established.**

This contract is the architectural source of truth for Phase 3 historical-import schema, command, reconciliation, and security implementation. No production or staging data was modified by T046.
