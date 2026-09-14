# P8-T136 Verification

T136 verifies the keyboard-wedge barcode scanner input contract without requiring production data or a physical scanner in CI.

## Acceptance evidence

1. Rapid scanner-style key sequences are reconstructed exactly.
2. Enter terminates a scan.
3. Inter-key gaps over 80 ms reset the accumulated buffer.
4. Values below four characters are rejected by default.
5. Spaces and punctuation are preserved.
6. The parser is deterministic and dependency-free.
7. Automated tests exercise all acceptance cases.

Physical scanner/device execution is intentionally outside this repository-only verification boundary and is handled by subsequent hardware regression work.
