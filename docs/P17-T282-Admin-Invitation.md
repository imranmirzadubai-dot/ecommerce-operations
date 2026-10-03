# P17-T282 — Admin Invitation Contract

The admin invitation flow is server-side only.

- Supabase Auth remains the identity system.
- The Worker requires an authenticated active Admin actor.
- The Supabase secret key is read only from the Worker environment and is never sent to the browser.
- Allowed roles are Sales, Operations, and Admin.
- The invited Auth user is provisioned into `public.profiles` through the trusted `provision_invited_profile` database function.
- Invitation/profile-provisioning failures are returned without exposing upstream secrets or credentials.
- Privileged invitation activity is logged through the trusted server path.
- This contract introduces no production data mutation by itself.
