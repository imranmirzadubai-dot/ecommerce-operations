# Access Control and Authorization Boundary Review

**Audit item:** AUD-P1-010  
**Scope:** Static review of the role model, database foundation policies, transactional command layer, and Cloudflare Worker RPC/read routes on `main`.

**Reviewed sources:** `supabase/migrations/20260910212711_database_foundation_v4.sql`, `supabase/migrations/20260912090000_profiles_role_model.sql`, `supabase/migrations/20260911120000_transactional_commands_core.sql`, and selected handlers in `worker/index.ts`.

**Execution boundary:** Read-only source review. No authenticated requests were sent, no secrets were read, no database was accessed, and no application code, policy, migration, workflow, or schema was changed.

## Executive summary

The architecture establishes several strong baseline boundaries:
- Application roles are constrained to `sales`, `operations`, and `admin`.
- `app_role()` derives the active role from the authenticated user's profile, rather than trusting a role supplied by the browser.
- Core tables have row-level security enabled.
- The initial policy set gives operational roles read access to operational tables and restricts audit logs and import data to admins.
- Core state-changing operations are exposed through `SECURITY DEFINER` functions with explicit role checks, and browser roles are intended to have no direct table-write grants.
- The Worker forwards the caller's access token to Supabase RPC calls and uses an explicit command allowlist.

This is a source-level assessment of selected files, not a complete authorization certification. The critical next step is a full inventory of every exposed RPC, policy, grant, and Worker route, followed by role-matrix tests against an isolated test environment.

## Observed controls

### Role model and profile

- The profile role constraint permits only `sales`, `operations`, or `admin`.
- `app_role()` is `SECURITY DEFINER`, uses a fixed `search_path`, and returns the role only for `auth.uid()` when the profile is active.
- The profiles table has RLS enabled and an authenticated self-select policy.
- The reviewed role-model migration revokes direct profile privileges from `anon` and `authenticated`, then grants authenticated users select access; role changes are described as command-owned.

### Database access

- The foundation migration enables RLS on core customer, order, parcel, COD, invoice, event, audit, and import tables.
- The initial policy set grants authenticated operational-role reads for operational data.
- Audit-log and import-table reads are admin-only in the reviewed initial policy set.
- The transactional command layer uses `SECURITY DEFINER` functions with `search_path = pg_catalog, public`, explicit authentication/role checks, and restricted function execution grants.

### Worker boundary

- RPC calls are limited by an explicit `ALLOWED_COMMANDS` set and require POST plus a bearer access token.
- The Worker forwards the caller's access token to Supabase; the reviewed RPC handler does not replace it with the service-role key.
- Selected read routes require a bearer token and rely on Supabase's authorization/RLS behavior for row access.
- A separate `SUPABASE_SECRET_KEY` is used by admin invitation/recovery flows, so those handlers need particularly careful actor-role checks and must never expose the key to the client.

## Findings and verification gaps

| ID | Finding | Risk | Evidence / limitation |
|---|---|---|---|
| AUTH-01 | A complete route-to-RPC-to-policy authorization matrix is not established by this targeted review. | High until verified | The Worker exposes multiple read routes and an RPC allowlist, while authorization also depends on SQL function grants, function-local checks, table grants, RLS policies, and later migrations. Selected files cannot prove the complete surface is consistent. |
| AUTH-02 | Operational read policies allow all three active roles to read broad operational tables; whether this is appropriate for each field and role needs explicit data-minimization review. | Medium | The foundation policy examples use `app_role() in ('sales','operations','admin')` for operational tables. This review did not establish field-level or row-level separation beyond those policies. |
| AUTH-03 | Security-definer functions require a full inventory of execute grants and internal authorization checks. | High until verified | Selected core functions show fixed search paths and explicit checks, but a selected-source review cannot prove every exposed function has the same safeguards or that no unintended function remains executable by PUBLIC/anon. |
| AUTH-04 | Privileged invitation and recovery routes require dedicated negative tests and verification of actor authorization before service-key operations. | High until verified | `worker/index.ts` uses `SUPABASE_SECRET_KEY` in admin invitation/recovery-related flows. This review did not exercise these routes or inspect every branch in full. |
| AUTH-05 | Self-profile read policy and role lookup should be tested for inactive users, missing profiles, and attempted role escalation. | Medium | `app_role()` filters on active profile and role changes are intended to be command-owned; runtime behavior was not tested. |
| AUTH-06 | RLS enabled is necessary but not sufficient; effective protection also depends on grants, policies, function ownership, and the caller identity passed upstream. | High until verified | Source confirms RLS is enabled for the initial core tables, but no live privilege catalog or deployed-schema comparison was performed. |

## Required role-matrix acceptance tests

Run only in an isolated disposable test database or a separately approved staging window. No tests were run for this audit item.

1. **Anonymous:** Direct table reads/writes and RPC calls are denied unless explicitly documented as public.
2. **Inactive user:** An authenticated user with an inactive profile receives no operational access and cannot call state-changing commands.
3. **Missing profile:** A valid Auth user without an application profile cannot gain a role by crafting request fields.
4. **Sales role:** Can perform only the documented sales actions; cannot administer users, access admin-only import/audit data, or perform operations/admin-only financial actions.
5. **Operations role:** Can perform only documented fulfillment/courier/COD actions; cannot administer users or access admin-only import/audit data.
6. **Admin role:** Can perform documented administrative actions, with every action auditable.
7. **Client role spoofing:** Supplying `role=admin`, alternate user IDs, or profile fields in request JSON does not elevate access.
8. **Direct table writes:** Authenticated and anonymous clients cannot bypass command-owned writes by calling PostgREST table endpoints directly.
9. **RPC privilege inventory:** For every function in the Worker allowlist, verify execute privileges, role checks, input validation, and fixed search path; verify unlisted functions cannot be invoked by the intended client roles.
10. **Object ownership/relationship:** IDs belonging to another order/customer/parcel cannot be combined to mutate cross-entity records.
11. **Admin invitation:** Non-admin caller, missing token, expired token, invalid role, and upstream failure do not create or retain an unauthorized user/profile.
12. **Recovery failure:** A failed profile provision or cleanup leaves no usable orphan account, or produces a documented alert and operator recovery path.
13. **Read-route coverage:** Test orders, timeline, customer history, and every other read route as anonymous, inactive, sales, operations, and admin.
14. **RLS drift:** Compare deployed staging policies and grants with migration expectations in a read-only report; do not reset or repair the database as part of this test.
15. **Secret isolation:** Confirm privileged keys are available only as server-side secrets and are never returned, logged, or bundled into browser assets.

## Recommendations

- Build and maintain a single authorization matrix linking every Worker route and command to its SQL function, execute grant, role check, table privileges, RLS policies, and expected roles.
- Inspect all migrations—not only the foundation migration—for policy replacement, additional grants, and function signature changes. Compare the expected policy/grant state with staging through read-only catalog queries under separately approved access.
- Keep role derivation server/database-owned. Never trust role claims or user IDs supplied in request bodies.
- Review data minimization per role; operational table-wide read access should be justified against actual screens and job duties.
- Add negative authorization tests to CI using isolated fixtures, including inactive/missing profiles, cross-entity IDs, direct PostgREST writes, and direct RPC invocation.
- Keep privileged service keys server-side and tightly scoped. Verify admin invitation/recovery checks and cleanup behavior before treating those paths as production-ready.
- Preserve fixed search paths and explicit execute grants for every `SECURITY DEFINER` function.

## Limitations

- No live production or staging authorization state was queried.
- No authenticated or anonymous HTTP request was sent.
- No full inventory of every migration, function, route, grant, or policy was completed in this item.
- No secrets or user data were read.
- No changes, deployment, database reset, or merge occurred.

## Recommendation

Mark this targeted static review complete, with authorization-matrix verification pending. Treat AUTH-01, AUTH-03, and AUTH-04 as priority verification items before claiming the complete application access-control boundary is proven. Any fixes require a separate PR and isolated tests; do not alter production schema or data without explicit authorization.
