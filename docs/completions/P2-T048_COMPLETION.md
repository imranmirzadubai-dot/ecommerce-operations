# P2-T048 Completion Record

## Task

**P2-T048 — Formalize UTC/AED/Asia-Dubai rules**

## Status

**COMPLETE — Phase 2 architecture formalization**

## Evidence commit

`19e8652201d4ff64481ebbe47eba22834979889d`

## TCR

`ECO-TCR-P2-T048-20260912-19e86522`

## Deliverables

- `docs/architecture/UTC_AED_ASIA_DUBAI_RULES.md`
- `docs/test-plans/T048_UTC_AED_ASIA_DUBAI_TEST_PLAN.md`
- this completion record

## Contract frozen

- Authoritative instants use PostgreSQL `timestamptz`.
- UTC is canonical storage/transport representation.
- `Asia/Dubai` is the UAE business timezone.
- UAE business dates use Asia/Dubai midnight boundaries.
- Browser/device timezone never determines business-date logic.
- MVP operating currency is AED.
- Money uses exact decimal arithmetic server-side.
- Currency conversion is never silent.
- Historical source timezone is preserved when known and never guessed when unknown.

## Verification

The current staging foundation was inspected before formalization. Existing timestamp columns use `timestamp with time zone` where inspected, and the task introduces no staging or production data changes.

## Scope boundary

No production changes. No staging DDL. No migration. No currency conversion. No timestamp rewrite.

## Decision

**FORMALIZED — UTC storage, Asia/Dubai business timezone, and AED currency rules are frozen for the MVP.**

Next task: **P2-T049**.