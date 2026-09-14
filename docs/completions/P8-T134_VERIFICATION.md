# P8-T134 — Verification Record

The invoice barcode renderer was exercised through a scanner-style decoder that reconstructs alternating black/white run widths from the generated SVG and decodes Code 128-B symbols.

## Assertions

1. Generated bars begin at x=0 and consume the declared SVG width.
2. Every bar position and width is aligned to the renderer's 2-module pixel width.
3. START symbol 104 and STOP symbol 106 are recognized.
4. Decoded data is checksum-validated using the Code 128-B weighted checksum.
5. Representative values round-trip exactly: `PCL-000001`, `PKG123456789`, `ABC 123`, and `PCL/2026-09-14-000123`.
6. The printed human-readable value and accessibility label match the value being encoded.

The validation is deterministic and automated. Physical scanner and paper/printer validation remain separate gates under P8-T135/P8-T136.

No production data changes.
