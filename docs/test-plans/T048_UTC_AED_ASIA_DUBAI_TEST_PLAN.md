# T048 UTC / AED / Asia-Dubai Test Plan

## Acceptance matrix

| ID | Scenario | Expected |
|---|---|---|
| T048-01 | Store an authoritative event timestamp | Stored as timezone-aware `timestamptz` |
| T048-02 | Read/write an instant through API | Same instant after round trip |
| T048-03 | UTC timestamp crosses UAE midnight | Business date follows Asia/Dubai, not UTC |
| T048-04 | Filter for UAE business date | Includes exactly the Asia/Dubai calendar-day interval |
| T048-05 | Month boundary near midnight | Correct UAE-local month assignment |
| T048-06 | Year boundary near midnight | Correct UAE-local year assignment |
| T048-07 | Client machine timezone differs from UAE | Business-date result unchanged |
| T048-08 | Asia/Dubai date conversion | UTC+04 behavior is deterministic |
| T048-09 | DST transition test | No artificial DST shift for Asia/Dubai |
| T048-10 | Report daily totals | Uses Asia/Dubai business-day boundaries |
| T048-11 | Export business date | Derived from Asia/Dubai while preserving instant |
| T048-12 | AED money field | Currency is AED and amount is exact decimal |
| T048-13 | Non-AED currency submitted to AED-only MVP | Rejected unless an explicitly approved future contract exists |
| T048-14 | Currency omitted where contract requires explicit currency | Validation failure |
| T048-15 | Monetary calculation | Server-side exact decimal result |
| T048-16 | Browser floating-point total differs from server | Server remains authoritative |
| T048-17 | Currency conversion requested | No silent conversion; explicit unsupported/approved path |
| T048-18 | Historical timestamp includes source timezone | Preserve source instant |
| T048-19 | Historical timestamp has unknown timezone | Validation/reconciliation failure; no guessed timezone |
| T048-20 | Audit/event timestamp display | Localized display does not alter stored instant |

## Phase 3 verification layers

1. PostgreSQL column types and constraints.
2. API schema validation.
3. Server-side date-range construction.
4. Frontend timezone-independent business logic.
5. Financial arithmetic tests.
6. Historical-import validation.
7. Report/export boundary tests.

## Exit criteria

The T048 architecture contract is version-controlled, the acceptance scenarios are explicit, and the Phase 3 implementation gaps are documented without changing live business data during Phase 2.