# P8-T135 — Validate physical paper/printer workflow

## Scope
Validate the generated invoice's physical-print contract before hardware-specific scanning validation.

## Verification
- Explicit A4 page size and 12 mm print margins via `@page`.
- Invoice content constrained to the intended printable A4 width.
- Print media rule removes the screen-oriented max-width constraint.
- Parcel Code 128 SVG has a deterministic 72 mm × 24 mm physical print box.
- Barcode uses crisp-edge rendering appropriate for 1D printed bars.
- Print-critical fields remain present: invoice number, Order ID, date, tracking ID, parcel barcode, customer, items, and total order amount.
- Template version and generation timestamp remain visible in the printable document.
- White page/background and structured table borders are explicitly defined.
- Renderer remains deterministic and has no screen-only media dependency.

## Boundary
This milestone validates the software-generated print contract and physical dimensions. It does not claim successful output from a specific printer, paper stock, operating-system print dialog, or physical scanner; those hardware gates are handled by P8-T136 and subsequent regression work.

## Data safety
No production data changes are introduced by this validation work.
