# P8-T136 — Validate hardware scan input mode

## Scope
Validate the software input contract for a USB/Bluetooth barcode scanner operating in keyboard-wedge mode.

## Verification
- Scanner characters are accumulated from keyboard events.
- `Enter` is treated as the scanner terminator.
- Rapid inter-key timing is accepted using an 80 ms default threshold.
- A gap above the threshold resets the buffer, separating normal human typing from scanner input.
- Minimum accepted value length defaults to four characters.
- Punctuation and spaces emitted by scanners are preserved.
- The parser is dependency-free and suitable for integration with browser keyboard input.
- Automated contract tests cover successful scan, incomplete scan, timeout reset, minimum length, and punctuation/space handling.

## Boundary
This validates keyboard-wedge input behavior in software. It does not claim that a specific physical scanner model, USB/Bluetooth adapter, operating system, or browser was physically connected during CI. Physical hardware regression remains a later gate.

## Data safety
No production data changes are introduced by this validation work.
