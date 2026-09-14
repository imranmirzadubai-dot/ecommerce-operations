# P8-T136 — Validate hardware scan input mode

T136 validates keyboard-wedge scanner input as a deterministic software contract: rapid key accumulation, Enter termination, timeout reset, minimum accepted length, and preservation of scanner-emitted punctuation/spaces. Automated tests cover the acceptance cases. No production data changes. Physical device execution remains a later hardware regression gate.
