# Engineering Incident Control Namespace

## Purpose

Keep milestone/task identifiers separate from engineering incident, defect, and evidence identifiers.

## Identifier classes

| Class | Pattern | Meaning |
|---|---|---|
| Milestone/task | P14-T227 | Existing product/milestone work item |
| Incident | INC-YYYY-MM-DD-NNN | A runtime or operational incident |
| Defect | DEF-<AREA>-NNN | A confirmed engineering defect |
| Evidence | EVD-<AREA>-NNN | A reproducible evidence bundle |

## Current incident

- **Incident:** INC-2026-09-22-001
- **Description:** Authentication/browser startup failure investigated during September 2026.
- **Related milestone:** P14-T227 (hardware regression)
- **Rule:** P14-T227 must not be reused as the identifier for the authentication/browser incident.

## Current confirmed defect

- **Defect:** DEF-ARCH-001
- **Description:** Duplicate OrdersWorkspace module resolution created an OrdersWorkspace/OrderBatchSelection recursive dependency.
- **Related incident:** INC-2026-09-22-001
- **Next structural control:** ARCH-002

## Evidence namespace

Browser reproductions and diagnostic bundles use **EVD-*** identifiers and must record the repository commit, environment, browser, test name, and retained failure artifacts.

## Control rule

A task may reference an incident, defect, or evidence item, but those identifiers remain independent of milestone/task IDs.
