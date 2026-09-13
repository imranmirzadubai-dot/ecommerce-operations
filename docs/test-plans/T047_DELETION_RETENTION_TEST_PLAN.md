# T047 Deletion and Retention Test Plan

## Purpose

Verify the deletion/retention architecture contract before Phase 3 implementation. Tests are design-level acceptance criteria and must not be treated as proof of current implementation.

## Test matrix

| ID | Scenario | Expected result |
|---|---|---|
| T047-01 | Attempt direct DELETE of an order as normal application role | Denied |
| T047-02 | Attempt direct DELETE of parcel/history as normal application role | Denied |
| T047-03 | Cancel an eligible order | State changes; historical rows remain |
| T047-04 | Cancel a prepared parcel | Parcel history remains; no hard deletion |
| T047-05 | Query cancelled order by UUID/immutable order number | Record remains addressable |
| T047-06 | Attempt to reuse an existing order number after deletion/cancellation | Rejected / never generated |
| T047-07 | Attempt identifier renumbering after cancellation | Rejected by command contract |
| T047-08 | Create corrected financial record | New adjustment/evidence; prior record unchanged |
| T047-09 | Correct a delivery outcome | New authorized evidence; prior outcome retained |
| T047-10 | Retry an import correction using same source file | Prior batch remains; retry follows explicit import identity rules |
| T047-11 | Import corrected source payload with same source identity | Conflict/reconciliation path; prior evidence not overwritten |
| T047-12 | Attempt DELETE of audit evidence | Denied |
| T047-13 | Attempt UPDATE of audit evidence | Denied |
| T047-14 | Attempt UPDATE of immutable domain event | Denied |
| T047-15 | Delete parent with dependent historical records | Referential integrity prevents orphaning |
| T047-16 | Verify no ordinary cascade deletes transactional history | Historical rows remain |
| T047-17 | Approved privileged deletion request | Only explicitly eligible records can be deleted |
| T047-18 | Deletion request without required authorization/approval | Denied |
| T047-19 | Destructive action audit evidence | Actor, target, reason, timestamp and correlation data recorded |
| T047-20 | Privacy/anonymization request | Dedicated controlled workflow; business/audit relationships preserved as required |
| T047-21 | Failed destructive operation | No partial deletion or inconsistent history |
| T047-22 | Recovery after approved destructive operation | Documented recovery path is available where required |
| T047-23 | Normal roles inspect retained operational history | Authorized reads succeed |
| T047-24 | Normal roles attempt deletion through an alternate API/helper path | Denied; no helper bypass |
| T047-25 | Service-role backend operation | Backend-only; originating actor and audit context preserved |

## Verification layers

1. PostgreSQL privileges and RLS.
2. Foreign-key and constraint behavior.
3. Transactional command authorization.
4. Audit/event immutability.
5. Identifier immutability/non-reuse.
6. Import lineage preservation.
7. Failure and rollback behavior.

## Current baseline verification

The staging database currently has UUID primary keys on `import_batches` and `import_rows`, and a unique `(batch_id, source_row_number)` constraint for import-row identity. The deletion policy does not modify this schema during Phase 2.

## Exit criteria

T047 passes when the policy is version-controlled, all applicable acceptance scenarios are defined, implementation gaps are explicitly mapped to later work, and no destructive database change was introduced merely to formalize the policy.