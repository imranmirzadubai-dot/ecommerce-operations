# Application Dependency Graph and Workspace Boundary Map

**Task:** ARCH-006  
**Baseline:** `fe48edd4da51e7c1e93a651dc016079b199bb26f`  
**Purpose:** authoritative architecture reference for subsequent implementation tasks.  
**Runtime impact:** none.

## 1. Runtime layers

```
Browser
  |
  v
src/main.tsx
  |
  +--> ErrorBoundary
  +--> ErrorReportingBootstrap
  +--> AuthProvider (src/lib/AuthContext.tsx)
          |
          v
      RouteGuard (src/RouteGuard.tsx)
          |
          v
        App (src/App.tsx)
          |
          +--> workspace components
          |
          +--> lib/auth.ts
          +--> lib/commands.ts
          +--> lib/routes.ts
          +--> lib/money.ts
          
Browser API boundary
  |
  v
Cloudflare Worker (worker/index.ts)
  |
  +--> /api/auth/*
  +--> /api/orders
  +--> /api/orders/:id/timeline
  +--> /api/customers/:id/history
  +--> /api/commands/:command
  |
  v
Supabase Auth / REST / PostgreSQL
```

## 2. Application entry and authentication boundary

- `src/main.tsx` is the browser bootstrap and owns the React root.
- `AuthProvider` owns authentication state, restore, refresh, sign-in/sign-out, operation generation, cancellation, and cross-tab session synchronization.
- `RouteGuard` is the protected-route gate and delegates the authenticated application to `App`.
- `App.tsx` is the current authenticated application shell and workspace composition point.
- `lib/auth.ts` is the browser authentication client. Refresh/session transport is Worker-mediated; profile retrieval is a direct Supabase REST read using the bearer access token.
- The Worker owns the refresh-token cookie boundary and authentication endpoints.

## 3. Workspace composition

The current application shell mounts these operational areas from `App.tsx`:

- `AdminUserControls`
- `CustomerHistoryWorkspace`
- `DispatchScanWorkspace`
- `RtoScanWorkspace`
- `OrdersWorkspace`
- `ReportWorkspace`
- `InvoicePrintWorkspace`
- `OrderExport`

The application currently renders several authenticated workspaces eagerly. **UI-004** is the later task responsible for changing that behavior; this document does not prescribe a runtime change.

## 4. Orders data boundary

`OrdersWorkspace` is the authoritative Orders data producer.

`OrderListRow` is defined in `src/lib/commands.ts` and is the typed row contract consumed by Orders-related presentation and export logic.

Current post-UI-002 flow:

```
OrdersWorkspace
    |
    | onOrdersChange(OrderListRow[])
    v
OrderBatchSelection
    |
    +--> selection state
    |
    +--> OrderExport
```

The batch-selection layer no longer derives business state from the DOM. `OrderExport` likewise consumes typed order data rather than scraping rendered table rows.

## 5. Worker API boundary

`worker/index.ts` is the server-side request boundary.

It currently exposes:

- authentication/session endpoints;
- bounded Orders listing with page/page-size validation;
- order timeline reads;
- customer history reads;
- an allow-listed RPC command endpoint.

Browser state-changing commands are sent through `/api/commands/:command` with a bearer access token.

## 6. Architectural dependency rules

1. UI business state must originate from typed React state/data contracts, not rendered DOM inspection.
2. Workspace components must not re-enter each other through recursive module dependencies.
3. Authentication state is owned by `AuthProvider`; components consume it through `useAuth`.
4. Browser command mutations use the Worker command boundary rather than direct arbitrary database RPC calls.
5. Refresh tokens remain behind the Worker HttpOnly cookie boundary.
6. The Worker is the authoritative server-side boundary for authenticated session transport and operational command routing.
7. Architecture documentation describes the current system; later tasks may change behavior only through their explicit task scope.

## 7. Known controlled exceptions / follow-on work

- **UI-004:** reduce eager authenticated workspace mounting.
- **UI-005:** move report filtering/pagination to bounded server-side APIs.
- **API-004:** inventory and consolidate remaining direct browser Supabase access.
- **ARCH-005:** CI source-graph guard detects duplicate logical stems and circular imports; it is already active.
- **T227 diagnostics:** diagnostic query parameters and workspace controls are test instrumentation, not the normal application navigation contract.

## 8. Verification

The source graph guard at `scripts/check-source-graph.mjs` is the machine-enforced structural check for duplicate logical source stems and circular imports. The current mainline CI also runs lint, typecheck, unit tests, source-graph validation, build, E2E, and database validation.

This document is an architectural map, not a claim that every future boundary has already been fully migrated. Follow-on tasks retain ownership of the migrations explicitly listed above.
