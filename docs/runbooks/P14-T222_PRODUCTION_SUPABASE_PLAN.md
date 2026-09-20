# P14-T222 — Production Supabase Plan Selection

## Decision

Target the **Supabase Pro plan** for the production organization/project when production billing is enabled.

## Basis

The project is a production operational system using Supabase PostgreSQL and Auth. The selected target must avoid Free-plan pausing and provide automatic database backups. Pro provides an 8 GB included database disk allowance, 250 GB included egress, 100,000 included MAU, daily backups with 7-day retention, and no inactivity pausing. Compute is separately configurable and paid plans include compute credits.

## Cost-control baseline

Start with the smallest appropriate compute size and increase only when measured workload requires it. Supabase currently lists Pro at $25/month and a Micro compute instance at $10/month, with $10/month in compute credits on paid plans. Usage-based charges can apply above included quotas. Keep spend cap enabled unless an explicit scaling decision requires otherwise.

## Backup / recovery implications

Pro daily backups provide a baseline recovery source. Point-in-Time Recovery is a separate paid add-on and is not assumed to be enabled by this milestone. P14-T223/P14-T224/P14-T225 cover logical exports, off-site backups and restore testing.

## Plan boundaries

Team and Enterprise are not selected as the initial target because this milestone has not established a requirement for their additional organizational/security/compliance controls or enterprise support/SLA features. This is a documented project target, not a claim that those plans are unnecessary forever.

## Environment status

Repository tooling confirms the production Supabase project `ecommerce-operations-production` is ACTIVE_HEALTHY in `ap-south-1`, PostgreSQL 17.6.1.166. The available project metadata does not expose the organization's current billing-plan state, so this milestone does **not** claim that the production organization has already been upgraded to Pro.

## Required human/control-plane action

If the organization is currently Free, an authorized owner must change the organization's subscription to Pro through the Supabase billing control plane. No billing change is executed by this repository milestone.

## Sources

- Supabase pricing: https://supabase.com/pricing
- Supabase billing: https://supabase.com/docs/guides/platform/billing-on-supabase
- Supabase backups: https://supabase.com/docs/guides/platform/backups
