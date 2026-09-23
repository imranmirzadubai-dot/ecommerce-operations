# Application Dependency Graph and Workspace Boundary Map

## Status

- Task: ARCH-006
- Baseline: main after ARCH-002, ARCH-003 and ARCH-004 structural fixes.
- Runtime behavior: no intended runtime change.

## Bootstrap

```
src/main.tsx
  -> ErrorBoundary
  -> ErrorReportingBootstrap
  -> AuthProvider
  -> RouteGuard
  -> App
```

RouteGuard owns protected-path admission. App owns the authenticated operations UI composition.

## Core dependency graph

```
main
├── RouteGuard
│   ├── AuthContext
│   ├── routes.ts
│   └── App
│       ├── AuthContext
│       ├── auth.ts
│       ├── routes.ts
│       ├── commands.ts
│       ├── OrdersWorkspace
│       │   ├── commands.ts
│       │   └── money.ts
│       ├── OrderExport
│       │   ├── excel.ts
│       │   └── ReportWorkspace
│       ├── InvoicePrintWorkspace
│       ├── CustomerHistoryWorkspace
│       ├── DispatchScanWorkspace
│       ├── RtoScanWorkspace
│       └── AdminUserControls
│
AuthContext
└── auth.ts
    └── roles.ts

OrdersWorkspace
└── commands.ts
    └── /api Worker boundary

Worker
├── authentication / bearer-token boundary
├── command allow-list
├── /api/orders
└── Supabase REST/RPC boundary

Supabase
└── database tables, functions, policies and migrations
```

## Workspace boundaries

| Boundary | Allowed dependencies | Forbidden coupling |
|---|---|---|
| Bootstrap | RouteGuard, AuthProvider, error reporting | Feature/business components directly in main |
| Routing | Auth state, route helpers, App | Direct database/API operations |
| App shell | Auth, route helpers, operational workspaces, command client | Workspace-to-workspace startup dependencies |
| Orders | Commands, money normalization, own UI state | Re-entering OrdersWorkspace from selection helpers |
| Batch selection | Selection state, export/status components | Owning or re-mounting the Orders workspace |
| Export | Export utility and typed order data | DOM scraping; implicit ReportWorkspace mounting |
| Reports | Report data/filtering/export utilities | Reading raw UI state from Orders |
| Auth | Auth transport, roles, session lifecycle | Workspace-specific UI logic |
| Browser command client | Worker API contracts | Direct database RPC from feature components |
| Worker | Authenticated validation, bounded API calls, Supabase boundary | Browser UI state or React components |
| Database | RLS/functions/data integrity | Browser-specific rendering concerns |

## Confirmed structural hazards

1. ARCH-002 removed the duplicate `src/components/OrdersWorkspace.ts`; canonical `.tsx` remains.
2. ARCH-004 removed duplicate `src/lib/routes.mjs`; canonical `src/lib/routes.ts` remains.
3. `OrderBatchSelection.tsx` currently imports and mounts `OrdersWorkspace`. This coupling remains documented for later UI cleanup; ARCH-006 does not silently redesign it.
4. `OrderExport.tsx` currently reads visible table rows through DOM queries and mounts `ReportWorkspace`. This remains a documented UI-001/UI-003 concern.
5. This document is an architectural control artifact; it does not claim all existing boundaries are already ideal.

## Architectural rules

- One authoritative source module per logical component/module stem.
- No extensionless import may resolve through a duplicate logical stem.
- Workspace components must not recursively mount their own parent workspace.
- Selection, export, reporting and operational workspaces should communicate through typed data/contracts rather than DOM scraping.
- Feature components should use the Worker/API boundary for operational reads/writes unless a documented exception exists.
- Route authority is `src/lib/routes.ts`.
- Auth lifecycle is owned by `AuthContext.tsx` and `auth.ts`.
- Structural source-graph checks remain mandatory.

## Verification basis

The graph was produced from the current main source after the ARCH-002 and ARCH-004 merges. Remaining coupling is recorded explicitly as follow-up work rather than changed as part of ARCH-006.
