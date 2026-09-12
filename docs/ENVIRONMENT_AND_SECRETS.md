# Environment & Secrets Strategy

## Purpose

Define the separation of local, feature/preview, staging and production environments before application feature development.

## Environment Contract

| Environment | Git context | Runtime | Database | Data rule |
|---|---|---|---|---|
| Local | developer working tree | Local React/Vite + local Cloudflare-compatible development | Local Supabase CLI stack | Synthetic/local data only |
| Feature / Preview | `feature/*` | Cloudflare Worker preview | No production data; isolated/test database only when required | Test data only |
| Staging | `develop` | Cloudflare staging deployment | Supabase staging | Shared pre-production data only |
| Production | `main` | Cloudflare production Worker | Supabase production | Live business data only after required foundation gates pass |

## Secret Rules

1. No passwords, API tokens, service-role/secret keys or private keys are committed to Git.
2. No production secret values are placed in frontend source, browser bundles, public configuration or chat messages.
3. Browser-safe Supabase configuration may use the project's publishable key when required by the application contract.
4. Supabase service-role/secret credentials are server-side only and are never exposed to the browser.
5. Local development uses local-only credentials and local Supabase endpoints.
6. Staging credentials and production credentials are separate and must never be copied between environments.
7. Cloudflare runtime secrets are stored in Cloudflare's secret/configuration mechanism, not in repository files.
8. GitHub Actions secrets are used only for CI/CD values that the workflow genuinely requires.
9. Secret names may be documented; secret values must never be documented.

## Configuration Ownership

- GitHub: source code, migrations, tests, documentation and non-secret configuration templates.
- Cloudflare: Worker deployment configuration and runtime secrets for the corresponding environment.
- Supabase: database/auth services and project-specific credentials/configuration.
- Local machine: local development credentials and Docker/Supabase CLI state.

## Migration Rule

Database schema changes are created as version-controlled Supabase migrations. The Dashboard is not the source of truth for schema changes. The intended progression is:

`local migration/test → staging migration/verification → production migration after release approval`

Production schema must not be edited casually through the Dashboard.

## Production Protection

- Production business data remains blocked until the required Database & Security Foundation gate passes.
- Production deployments must come from the controlled production branch/release path.
- Production and staging credentials must remain isolated.
- Destructive production operations require explicit target verification and the project's destructive-action safeguards.

## Safe Templates

`.env.example` may contain variable names and non-secret placeholders only. Actual secret values belong in the appropriate environment's secret store or local untracked configuration.
