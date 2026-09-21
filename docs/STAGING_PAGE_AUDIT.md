# Staging Page Audit — P14-T227

Date: 2026-09-21

## Scope

Audit of the staging Cloudflare Worker page, React bootstrap path, authentication flow, navigation behavior, and deployment wiring after the staging Worker was provisioned.

## Findings

### Critical — duplicate authentication bootstrap

`RouteGuard` and `App` both called `restoreSession()` on protected pages. This caused two independent authentication/profile restoration flows during initial load. Because `restoreSession()` can refresh an expiring Supabase refresh token and writes the refreshed session to `localStorage`, concurrent calls could race and invalidate one another's refresh state. React development StrictMode can also exercise effects more than once.

**Remediation:** `RouteGuard` is now the single owner of initial session restoration and passes the resulting `AuthState` into `App`.

### High — full-page navigation after sign-in/sign-out

`App` used `window.location.replace()` after sign-in and sign-out. This forced another application bootstrap immediately after authentication state had already been established.

**Remediation:** sign-in/sign-out now update shared auth state and use `history.replaceState()` without forcing a full-page reload.

### Medium — authentication bootstrap had no visible loading shell

The route guard returned an empty element while checking authentication, making a slow or stalled authentication request appear as a frozen page.

**Remediation:** the guard now renders a minimal full-page `Checking secure access…` state while the single bootstrap request is pending.

### Medium — sidebar navigation is only partially wired

The sidebar renders Customers, Orders, Parcels, Dispatch, Delivery / NDR, COD & Finance, and Invoices as buttons, but the current `navigateTo()` implementation only performs an action for Reports. These controls therefore appear interactive but do not navigate to dedicated views.

**Status:** not part of the authentication-loop fix. The controls remain gated while signed out and should be wired as their respective workspaces/routes are implemented.

### Deployment safety observation — external Cloudflare Git integration

GitHub check-run data for the fix branch shows a Cloudflare Workers Builds check associated with the production Worker service context (`ecommerce-operations/production`). This is an external Cloudflare Git integration and is separate from the repository's manual `Deploy Staging` workflow.

The check is recorded as a build/check-run; this audit does **not** claim that production traffic or production data was changed. Cloudflare Git integration settings should be reviewed so non-main branch activity cannot unintentionally deploy production.

## Staging deployment contract

- Staging Worker: `ecommerce-operations-staging`
- Staging Supabase project ref: `mijbpvgxrxjaalimyqgm`
- Staging deployment is performed by `.github/workflows/deploy-staging.yml`.
- Production Worker remains `ecommerce-operations`.
- No database changes are included in this remediation.

## Verification required

After the fix is merged and deployed to staging:

1. Open the staging Worker in a clean browser session.
2. Confirm the page reaches the login form without repeated reloads or prolonged CPU/network activity.
3. Confirm sign-in changes the UI without a full-page reload loop.
4. Confirm sign-out returns to the login view without a reload loop.
5. Confirm an authenticated session does not trigger duplicate profile restoration requests.
6. Verify the browser remains responsive under repeated refreshes.
7. Continue with the physical T227 hardware regression separately; this audit does not mark T227 complete.
