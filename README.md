# E-Commerce Operations

MVP application for internal e-commerce operations.

## Technology

- React
- TypeScript
- Vite
- Cloudflare Workers
- Supabase PostgreSQL
- Supabase Auth
- GitHub + GitHub Actions

## Architecture

A single React + TypeScript + Vite application deployed as one Cloudflare Worker per environment. The Worker serves the frontend and server-side application/API layer. Supabase provides PostgreSQL and Auth.

There are no separately deployed frontend and backend services and no microservices in the MVP architecture.

## Repository Structure

```text
src/        Frontend application
server/     Server-side application/API and commands
packages/   Shared application packages and types
supabase/   Version-controlled database configuration and migrations
tests/      Unit, integration and end-to-end tests
docs/       Architecture, decisions and project documentation
scripts/    Development, validation and operational scripts
worker/     Cloudflare Worker entrypoint/configuration
```

## Environments

- Local → developer environment + local Supabase only
- Feature → review/optional preview; no production data
- Develop/Staging → staging Cloudflare + staging Supabase
- Main/Production → production Cloudflare + production Supabase

## Source of Truth

This repository is the source of truth for application code, database migrations, tests, documentation and deployment configuration. Business scope is governed by the locked MVP Blueprint; engineering implementation is governed by the Master Implementation Plan v4.0 FINAL.

## Security Baseline

- Production secrets must remain outside source control.
- Supabase service-role/secret keys must never be exposed to the browser.
- Database access rules and RLS are defined explicitly through version-controlled migrations.
- Production business data is blocked until the required foundation/security gates have passed.

## CI Baseline

Every feature-branch push and pull request runs lint, TypeScript typecheck, unit tests, build, and isolated local Supabase database tests before the foundation CI gate can be considered verified.
