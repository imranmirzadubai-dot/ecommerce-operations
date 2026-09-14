# P8-T136 Implementation

The hardware scan input contract is implemented in `src/lib/hardwareScanner.ts` as a dependency-free parser for keyboard-wedge scanner events. It recognizes Enter as the terminator, uses an 80 ms inter-key timeout by default, resets on longer gaps, enforces a four-character minimum by default, and preserves punctuation and spaces.
