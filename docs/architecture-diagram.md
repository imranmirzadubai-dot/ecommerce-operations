# E-Commerce Operations — Architecture Diagrams

These diagrams use Mermaid, which GitHub renders directly in Markdown.

## 1. Application and infrastructure

This diagram reflects the architecture documented in the repository README: one React + TypeScript + Vite application deployed as a Cloudflare Worker per environment. The Worker serves the UI and server-side API layer; Supabase provides PostgreSQL and Auth. This is not a microservices architecture.

```mermaid
flowchart TB
    USER["Operations team / admin user"]
    subgraph APP["Single application deployment — per environment"]
      UI["React + TypeScript + Vite UI<br/>src/"]
      API["Server-side API and commands<br/>server/"]
      SHARED["Shared packages and types<br/>packages/"]
      ENTRY["Cloudflare Worker entrypoint<br/>worker/"]
      UI --> ENTRY
      API --> ENTRY
      SHARED -. shared contracts .-> UI
      SHARED -. shared contracts .-> API
    end
    subgraph DATA["Supabase"]
      AUTH["Supabase Auth"]
      DB[("Supabase PostgreSQL")]
      MIG["Version-controlled migrations<br/>supabase/"]
      MIG --> DB
    end
    USER --> UI
    ENTRY --> AUTH
    ENTRY --> DB
    GH["GitHub repository<br/>source, tests, docs, configuration"]
    CI["GitHub Actions<br/>lint · typecheck · unit tests · build<br/>isolated local Supabase DB tests"]
    GH --> CI
    CI -. validated changes / deployment workflow .-> ENTRY
```

## 2. Environment separation

```mermaid
flowchart LR
    LOCAL["Local development<br/>local app + local Supabase"]
    FEATURE["Feature / preview<br/>optional review environment<br/>no production data"]
    STAGING["Develop / Staging<br/>staging Cloudflare Worker<br/>staging Supabase"]
    PROD["Main / Production<br/>production Cloudflare Worker<br/>production Supabase"]
    LOCAL --> FEATURE
    FEATURE --> STAGING
    STAGING --> PROD
    NOTE["Promotion is conditional on review, CI and required security/foundation gates."]
    STAGING -.-> NOTE
    PROD -.-> NOTE
```

The arrows represent the intended promotion path, not a claim that every deployment is fully automated.

## 3. Operational domain flow (high-level)

This is a conceptual view of the e-commerce operations lifecycle, based on the project’s known Orders, Customers, Parcels, Invoices, COD and Courier workstreams. Confirm individual transitions and database relationships against the current implementation before using this as a formal process specification.

```mermaid
flowchart TD
    CUSTOMER["Customer"]
    ORDER["Order created / managed"]
    COURIER["Courier assigned / managed"]
    PARCEL["Parcel and shipment tracking"]
    DELIVERY{"Delivery outcome"}
    COD["Cash on Delivery (COD)<br/>collection / reconciliation"]
    INVOICE["Invoice generation / management"]
    EXCEPTION["Failed delivery / return / exception handling"]
    CUSTOMER --> ORDER
    ORDER --> COURIER
    COURIER --> PARCEL
    PARCEL --> DELIVERY
    DELIVERY -->|Delivered| COD
    DELIVERY -->|Delivered or billable event| INVOICE
    DELIVERY -->|Failed / returned| EXCEPTION
    EXCEPTION --> ORDER
```

## 4. Repository map

```mermaid
flowchart TB
    REPO["ecommerce-operations"]
    REPO --> SRC["src/ — frontend"]
    REPO --> SERVER["server/ — API and commands"]
    REPO --> PACKAGES["packages/ — shared code and types"]
    REPO --> SUPABASE["supabase/ — config and migrations"]
    REPO --> TESTS["tests/ — unit, integration, E2E"]
    REPO --> DOCS["docs/ — architecture and decisions"]
    REPO --> SCRIPTS["scripts/ — development and validation"]
    REPO --> WORKER["worker/ — Cloudflare Worker entrypoint"]
```

## Security and architecture notes

- Keep production secrets out of source control.
- Never expose Supabase service-role or secret keys to the browser.
- Database access policies and Row Level Security (RLS) should be explicit in version-controlled migrations.
- Keep staging and production data environments separate.
- This document is a navigable architecture overview, not a substitute for the locked MVP Blueprint, Master Implementation Plan v4.0 FINAL, or verified schema/API contracts.
