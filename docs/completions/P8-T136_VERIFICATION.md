# P8-T136 — Verification Evidence

## Automated contract checks

`tests/unit/scanner_input_mode.test.mjs` verifies:

1. Keyboard-wedge/HID payload round-trip with an Enter terminator.
2. Trailing CR/LF transport terminators are normalized away.
3. Embedded control characters are rejected.
4. Non-character controls such as Shift/F1 do not modify the scan buffer.
5. Scanner payload length is bounded at 128 characters by default.

## Hardware boundary

The repository can validate the keyboard input contract but cannot emulate the electrical/USB/Bluetooth characteristics of a particular scanner. Therefore this evidence does not claim physical-device success.

## Production impact

No production data changes.
