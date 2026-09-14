# P8-T133 — Validate Code 128 barcode generation

## Outcome
The invoice barcode renderer is validated as Code 128-B for parcel-number values.

## Verification contract
- The full 107-symbol Code 128 table is present.
- Symbol 104 is used as the Code 128-B start symbol.
- Symbol 106 is used as the stop symbol.
- The checksum uses the Code 128-B weighted checksum formula.
- Representative parcel values have independently verified checksum vectors.
- Generated SVG structure contains the expected symbol sequence, module width, bar count, human-readable parcel value, and accessibility label.
- Human-readable barcode text is HTML-escaped.

## Scope
This milestone validates the existing renderer; it does not change the parcel barcode value or introduce production data changes.
