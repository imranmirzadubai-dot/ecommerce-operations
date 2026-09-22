# Environment Contract

## Purpose

Define one unambiguous production/staging contract before the next deployment work. The application must never silently cross-connect a staging browser or Worker to production Supabase resources.

## Environments

| Environment | Cloudflare Worker | Supabase target | Browser build selector |
|---|---|---|---|
| Production | `ecommerce-operations` | Production Supabase project | `CLOUDFLARE_ENV=production` / default production build |
| Staging | `ecommerce-operations-staging` | `mijbpvgxrxjaalimyqgm` (`https://mijbpvgxrxjaalimyqgm.supabase.co`) | `CLOUDFLARE_ENV=staging` |

## Configuration ownership

### Cloudflare Worker

`wrangler.jsonc` is the source of truth for Worker identity and environment-specific non-secret variables.

- The top-level Worker remains production: `ecommerce-operations`.
- The `staging` Cloudflare environment uses `ecommerce-operations-staging`.
- Staging `SUPABASE_URL` is explicitly pinned to the staging Supabase project.
- `SUPABASE_PUBLISHABLE_KEY` is not committed to the repository; it must be supplied as the appropriate Worker secret.

### Browser build

The following variables are build-time browser configuration:

- `VITE_APP_ENVIRONMENT`
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

The publishable key is allowed in browser code; service-role/secret keys are not.

For the Cloudflare Vite plugin, the active Cloudflare environment is selected **at build time** with `CLOUDFLARE_ENV`. The resulting build contains a flattened deployment configuration. Do not build one environment and attempt to retarget it later with `wrangler deploy --env`.

## Required staging values

- `CLOUDFLARE_ENV=staging`
- `VITE_APP_ENVIRONMENT=staging`
- `VITE_SUPABASE_URL=https://mijbpvgxrxjaalimyqgm.supabase.co`
- `VITE_SUPABASE_PUBLISHABLE_KEY=<GitHub staging environment secret>`
- Worker `SUPABASE_URL=https://mijbpvgxrxjaalimyqgm.supabase.co`
- Worker `SUPABASE_PUBLISHABLE_KEY=<Cloudflare staging secret>`

## Required production properties

Production deployment must continue targeting:

- Worker: `ecommerce-operations`
- Production Supabase project
- Production browser environment label
- Production Supabase publishable key

Existing production secrets/configuration are intentionally not copied into source control or this document.

## Safety rules

1. Staging and production must use different Supabase project targets.
2. Staging must deploy as `ecommerce-operations-staging`.
3. Production must remain `ecommerce-operations`.
4. Never place a service-role key in any `VITE_*` variable.
5. Environment selection must happen before `vite build`.
6. A staging build must not be deployed as production, and a production build must not be deployed as staging.
7. FIX-03 will add deterministic deployment isolation and automated configuration checks before staging is used for browser validation.
