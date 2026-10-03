# P17-T290 — Email Verification / Invitation State

Supabase Auth remains the sole identity and invitation system.

## State exposed to the application

The trusted Admin read path returns only the fields required for administration:

- `invited_at` — when the Auth invitation was created, when available.
- `confirmation_sent_at` — when Auth last recorded a confirmation/invitation email send.
- `email_confirmed_at` — when the user's email was confirmed; null means unverified.
- `confirmed_at` — Auth confirmation timestamp.
- `last_sign_in_at` — last recorded sign-in.
- `email_verified` — derived from `email_confirmed_at IS NOT NULL`.
- `invitation_pending` — derived as invited and not email-verified.

## Security boundary

- `auth.users` is not exposed through the generated client API.
- `admin_get_user_auth_state(uuid)` is `SECURITY DEFINER` with a pinned `search_path`.
- The function requires an authenticated active Admin through the existing `public.app_role()` authorization boundary.
- Browser/client code receives no Auth secrets, password material, recovery tokens, or service-role credentials.
- Existing `profiles` RLS is unchanged.
- This task is read-only and introduces no production data mutation.

## Source of truth

Invitation and email-verification state is read from Supabase Auth rather than duplicated into `public.profiles`. This prevents drift between the application profile and the actual authentication account state.

## UX interpretation

The eventual Admin user detail/list UI can display a clear account-state badge using the trusted result, for example: Invited / Verification Pending / Verified. The UI is informational only; authorization remains server-side.
