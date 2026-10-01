# UI-003 — UI Change Boundary

**Project:** E-Commerce Operations  
**Master Plan:** UI-MP-1.2  
**Baseline:** `dd6fe0227bec898889fb835e38c2f990dc34be07`  
**UI branch:** `ui/ui-mp-1.2-baseline-contract-audit`

## 1. Purpose

This document defines the hard boundary for the UI modernization project.

The UI project may change presentation, responsive layout, component composition and accessibility. It must not change the existing application's database, schema, business logic, authorization semantics, authentication semantics, state-machine rules or API/command contracts.

If a requirement crosses this boundary, stop the UI task and create a separately scoped task.

## 2. Allowed UI scope

The following are allowed when existing behaviour/contracts are preserved:

### Presentation
- `src/App.css`
- `src/index.css`
- UI-specific CSS/style files
- layout
- spacing
- typography
- responsive breakpoints
- colors/status presentation
- component visual states

### UI components
- `src/components/**`
- new presentation-only components under `src/components/**`
- responsive variants of existing components
- shared UI primitives
- accessibility improvements
- loading/empty/error/permission presentation

### App shell
- `src/App.tsx` may be changed for UI composition/navigation presentation.
- Existing command calls, auth checks, role checks and state-changing behaviour must remain semantically unchanged.

### Tests/evidence
- UI unit tests
- Playwright/browser tests
- visual regression evidence
- documentation under `docs/ui/**`

## 3. Protected application contracts

The following are protected from modification under ordinary UI tasks:

### Authentication / authorization
- `src/lib/auth.ts`
- `src/lib/AuthContext.tsx`
- `src/lib/roles.ts`
- `src/lib/routes.ts`
- authentication/session semantics
- role semantics
- permission checks

A UI task may present existing auth/permission states but may not redefine who is allowed to perform an operation.

### API / command contracts
- `src/lib/commands.ts`
- `src/lib/parcelCommands.ts`
- `src/lib/bulkDispatch.ts`
- `src/lib/bulkRto.ts`
- other command/RPC contract modules
- command names
- command input/output contracts
- API endpoint semantics

The UI must consume existing contracts.

### Invoice/report contracts
- existing invoice generation/rendering contract
- existing invoice PDF generation contract
- existing report data sources and report definitions

Presentation can change; authoritative report/invoice behaviour cannot.

### Backend
- `server/**`
- `worker/**`
- API handlers
- business-rule implementations
- backend validation
- transaction boundaries

### Database
- `supabase/migrations/**`
- `supabase/tests/database/**`
- DB functions/RPC definitions
- tables
- columns
- constraints
- indexes
- triggers
- RLS policies
- views
- seed/reset/restore operations

No UI task may reset, truncate, seed, migrate or restore a database.

## 4. Protected workflow semantics

The following must remain unchanged:

- order lifecycle transitions
- parcel lifecycle transitions
- allocation/split/correction rules
- tracking-ID uniqueness
- dispatch eligibility
- duplicate-scan idempotency
- delivery/NDR/RTO rules
- Lost/Damaged handling
- COD calculations and reconciliation
- append-only financial adjustments
- invoice print event recording
- report calculations/data sources
- admin-only controls
- authentication/session lifecycle

## 5. Scope exception process

If UI work genuinely requires a protected change:

1. Stop the UI implementation.
2. Document the exact dependency and why the existing contract cannot satisfy it.
3. Create a separate task outside the UI implementation task.
4. Obtain explicit scope approval.
5. Do not mix the protected change into the UI PR unless the separate task is deliberately combined and approved.
6. Record the exception in the milestone tracker.

An exception must never be created merely to make a mockup easier to implement.

## 6. CI enforcement target

UI-003A will enforce this boundary automatically.

The guard should fail a UI PR when protected paths are modified without an explicit approved scope exception.

Initial protected path classes:

- `supabase/migrations/**`
- `supabase/tests/database/**`
- `server/**`
- `worker/**`
- protected auth/permission modules
- protected command/API contract modules
- protected invoice/report contract modules

The guard must be designed so ordinary UI PRs cannot silently bypass it.

## 7. Restore rule

If an unexplained regression occurs:

**STOP → COMPARE → RESTORE CODE → VERIFY → RESUME**

Protected restore point:

`UI-RESTORE-GATE-2026-10-01`

Commit:

`dd6fe0227bec898889fb835e38c2f990dc34be07`

The UI project does not initiate database restoration.

## 8. UI-003 completion criterion

UI-003 is complete when:

- this boundary is committed;
- allowed paths are explicit;
- protected paths/contracts are explicit;
- protected workflow semantics are explicit;
- the scope-exception process is explicit;
- UI-003A is identified as the enforcement step.

No database or application contract has been changed by this task.
