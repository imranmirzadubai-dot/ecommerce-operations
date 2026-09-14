# P8-T136 — Validate hardware scan input mode

## Scope
Validate the MVP's expected barcode scanner input mode as a keyboard-wedge/HID text stream, using the browser's normal keyboard input path rather than a proprietary device driver.

## Verification
- Scanner payload is accepted as printable ASCII barcode text.
- Enter/CR/LF may terminate a scanner payload and are not retained as barcode data.
- Embedded control characters are rejected.
- Non-character keyboard controls do not alter the accumulated scan buffer.
- Maximum scanner payload length is enforced.
- A representative parcel barcode round-trips through the keyboard-wedge input contract.

## Boundary
This milestone validates the software input contract for keyboard-wedge/HID scanner mode. It does not claim a specific physical scanner, USB/Bluetooth transport, operating-system driver, or browser/device pairing was exercised. Physical device regression remains covered by the hardware regression gate.

## Data safety
No production data changes are introduced by this validation work.
