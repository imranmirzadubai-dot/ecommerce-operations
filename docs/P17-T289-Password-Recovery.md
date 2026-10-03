# P17-T289 — Admin Password Recovery

## Scope

Provide an Admin-only password-recovery initiation path for an existing application user without creating a second password system or exposing Supabase Auth administrative credentials to the browser.

## Architecture

- Supabase Auth remains the sole identity/password system.
- The browser calls `POST /api/admin/users/password-recovery` with the authenticated access token and target profile UUID.
- The Cloudflare Worker authenticates the caller through Supabase Auth and delegates target authorization to `public.prepare_admin_password_recovery(...)`.
- The database function requires the current actor to be an active Admin through `public.app_role()` and records a privileged audit event.
- The Worker uses the server-only `SUPABASE_SECRET_KEY` to call Supabase Auth `/auth/v1/recover` for the target email.
- The secret key, recovery token, and recovery link are never returned to the browser.
- The endpoint does not accept a client-controlled redirect URL. Supabase Auth uses the project's configured Site URL/redirect configuration, which is controlled outside the browser request.
- The existing P14-T227 password-recovery callback/screen remains the consumer of the recovery flow; no parallel recovery UI or token system is introduced.

## Security properties

- POST only.
- Missing/invalid bearer token is rejected.
- Target UUID is validated before database access.
- Target lookup and authorization occur through a SECURITY DEFINER function with pinned `search_path`.
- Function execution is revoked from `public` and granted only to `authenticated`.
- Target passwords, Auth secrets, recovery tokens, and action links are never persisted in application tables or returned in the response.
- No RLS policies are weakened.
- No service-role/secret key is present in frontend code.
- Recovery failures are logged without logging the target email, password, token, or action link.

## Response

Successful request returns only `{ ok: true, userId }`. Upstream Auth failure is normalized to a generic recovery-email failure response.

## Deployment boundary

This task changes GitHub source only. It does not mutate production. Staging verification must run through the existing staging deployment workflow before any later production gate.
