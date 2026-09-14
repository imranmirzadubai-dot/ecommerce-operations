# P8-T135 — Verification Evidence

## Automated contract checks

`tests/unit/invoice_print_workflow.test.mjs` verifies the invoice renderer source for:

1. A4 `@page` sizing with 12 mm margins.
2. 190 mm printable invoice width and print-media behavior.
3. 72 mm × 24 mm barcode print dimensions.
4. Crisp-edge SVG barcode rendering.
5. Presence of all print-critical invoice fields and historical template metadata.
6. White page/background and structured table layout.
7. Deterministic renderer contract with no screen-only media rule.

## Hardware boundary

No physical printer or paper device is available to this automated repository check. Therefore the evidence is intentionally limited to the deterministic printable HTML/CSS contract and its physical dimensions. A physical print/scan test must be performed at the hardware gate before claiming end-to-end device success.

## Production impact

No production data changes.
