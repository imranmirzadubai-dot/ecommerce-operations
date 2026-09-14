# P8-T134 — Validate scanner readability

Status: Complete when merged with required review and green CI.

## Scope

Validate that the existing invoice Code 128-B barcode output is structurally readable by a scanner-style decoder and preserves the parcel identity end-to-end.

## Verification

- Scanner-style run-length reconstruction from generated SVG bars.
- Code 128-B START and STOP recognition.
- Complete symbol lookup against the renderer's Code 128 table.
- Checksum verification after decoding.
- Round-trip verification for representative parcel values, including punctuation and spaces.
- Deterministic, module-aligned bar positions and widths.
- Human-readable parcel value and accessibility label remain aligned with the encoded value.

No production data changes.
