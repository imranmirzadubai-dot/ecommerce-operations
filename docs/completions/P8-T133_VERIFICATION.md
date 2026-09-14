# P8-T133 — Code 128 generation verification

The existing invoice barcode renderer is validated as Code 128-B.

Verification covers the complete 107-symbol table, Code 128-B start/stop symbols, independent checksum vectors, generated SVG structure and dimensions, bar count, parcel-value preservation, and HTML escaping.

No production data changes are introduced.
