# Staging deployment

The MVP uses separate Cloudflare Worker environments for staging and production. Staging must use the staging Supabase project and must never be pointed at production Supabase.

## Cloudflare Worker

- Production Worker: `ecommerce-operations`
- Staging Worker: `ecommerce-operations-staging`
- Staging publication: `*.workers.dev`
- Wrangler environment: `staging`

The staging environment is defined in `wrangler.jsonc` and is deployed with `CLOUDFLARE_ENV=staging` / `wrangler deploy --env staging`.

## Staging Supabase

- URL: `https://mijbpvgxrxjaalimyqgm.supabase.co`
- Project ref: `mijbpvgxrxjaalimyqgm`

Only the Supabase publishable key may be supplied to the browser. Service-role/secret keys must not be used in the frontend or committed to source control.

## GitHub Actions prerequisites

The `Deploy Staging` workflow is manual and uses the GitHub `staging` environment. Configure these environment secrets before running it:

- `CLOUDFLARE_API_TOKEN` — Cloudflare API token permitted to deploy Workers in the account.
- `STAGING_SUPABASE_PUBLISHABLE_KEY` — the staging Supabase publishable key.

The workflow hard-checks the staging Supabase URL and the staging Worker name before deployment.

## Deployment

1. Open GitHub Actions → `Deploy Staging`.
2. Run the workflow from the intended branch/commit.
3. Confirm the resulting Worker is `ecommerce-operations-staging`.
4. Open its `workers.dev` URL.
5. Confirm the application banner says `STAGING` and authentication is configured.
6. Only after those checks should T227 hardware regression be performed.

Production is not modified by the staging workflow.
