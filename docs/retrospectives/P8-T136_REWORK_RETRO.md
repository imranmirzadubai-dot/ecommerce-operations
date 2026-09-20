# P8-T136 Rework Retrospective

## Trigger
The 2026-09-16 technical audit identified seven T136 completion/verification documents and four consecutive scanner-parser harness fixes on 2026-09-14.

## Observed pattern
The fixes were:
- `bd46a77` — test(t136): fix scanner parser harness
- `0e420f8` — test(T136): preserve scanner constants in verification harness
- `77a20d4` — test: preserve scanner parser runtime constants
- `83514e3` — test: preserve scanner parser constants in runtime harness

## Root cause
The verification harness did not preserve runtime scanner constants consistently between the implementation and its test environment. Each subsequent correction restored another part of the runtime contract.

## Impact
The rework was confined to the T136 verification harness. The final implementation was merged and later dispatch tasks were built on the resulting scanner-input contract.

## Corrective process
For future hardware/timing-sensitive tasks:
1. Treat runtime constants and parser configuration as explicit test fixtures.
2. Validate the harness against the production module before changing assertions.
3. When the same harness fails twice, stop and document STATUS, VERIFIED, ASSUMPTION, IMPACT, ROOT CAUSE, OPTIONS and DECISION before another fix.
4. Keep one final completion document that links the implementation, verification and final CI result.

## Decision
No rollback or reimplementation of T136 is required. The corrective action is process hardening and evidence consolidation.
