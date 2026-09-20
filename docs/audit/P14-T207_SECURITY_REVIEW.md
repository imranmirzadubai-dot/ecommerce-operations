# P14-T207 — Full Security Review

**Review date:** 2026-09-20  
**Baseline:** `main` at `f8e65cdb0852e165e593dc64f1d7b956df51368f`  
**Scope:** Production Readiness Gate — application, authentication, authorization, database security boundaries, secrets/environment handling, reporting/export surface, CI controls, and deployment exposure.

## 1. Review method

This review is a repository-level security review of the current implementation. It covers:

- React/Vite authentication and session handling
- Route and UI authorization boundaries
- API command authentication
- Supabase RLS and grants represented by version-controlled migrations
- `SECURITY DEFINER` role lookup boundary
- Report views and report export access
- Environment and secret handling
- Browser exposure and client-side data handling
- CI quality/security controls visible in the repository
- Production-readiness gaps that are explicitly scheduled for later hardening milestones

This review does **not** claim that an external penetration test, browser dynamic security test, Cloudflare configuration audit, Supabase dashboard audit, or credential rotation test was performed. Those require environment-level access and are tracked separately where applicable.

## 2. Security controls confirmed

### Authentication

- Authentication uses Supabase Auth password and refresh-token grants.
- Authenticated profile loading requires the presented bearer token and the authenticated user's own profile ID.
- Inactive profiles are rejected and stored sessions are cleared.
- Authentication requests use an eight-second timeout.
- Sign-out clears the locally stored session before attempting the remote logout call.

### Authorization

- Operational access is restricted to active `sales`, `operations`, and `admin` profiles.
- User administration is restricted to active `admin` profiles.
- The database role contract is constrained to `sales`, `operations`, and `admin`.
- The database `app_role()` helper is `SECURITY DEFINER`, restricted to `authenticated` execution, and uses a fixed `search_path` of `pg_catalog, public`.
- Base tables have RLS enabled.
- Anonymous table access is revoked.
- Authenticated direct table access is SELECT-only in the foundation migration; state-changing operations are command-owned.
- Audit logs, historical import batches, and historical import rows are restricted to admins.

### Command/API boundary

- State-changing commands are invoked through authenticated bearer-token requests.
- Command names are URL-encoded client-side.
- Command bodies are JSON-encoded rather than interpolated into SQL.
- Existing command contracts include idempotency keys for state-changing operations.

### Reporting

- Phase 13 report views are read-only security-invoker views.
- Anonymous SELECT is revoked for report surfaces and authenticated SELECT is granted.
- Report UI requests include the authenticated access token as a bearer token.
- Report exports operate on returned authoritative report data and do not introduce VAT, discount, unit-price, or service-fee calculations.

### Secrets and environments

- Repository documentation explicitly prohibits committing passwords, API tokens, service-role keys, private keys, and production secret values.
- Browser configuration is limited to publishable Supabase configuration.
- Service-role/secret credentials are documented as server-side only.
- Staging and production credentials are required to remain separate.
- Cloudflare runtime secrets are intended to remain in the platform secret/configuration mechanism.
- Production business data is explicitly blocked until foundation gates pass.

### CI

- Pull requests to `main` run lint, typecheck, unit tests, build, and database reset/test execution.
- Database CI exercises a substantial set of transactional, lifecycle, COD, allocation, and authorization-related database tests.
- No secret values are required by the ordinary quality job.

## 3. Findings

### S-01 — Refresh token stored in browser localStorage

**Severity:** High  
**Area:** Authentication/session security  
**Status:** Open

`auth.ts` stores both the access token and refresh token in `localStorage`. Any successful JavaScript execution in the origin can read the refresh token. This increases the impact of an XSS compromise compared with an HttpOnly, Secure, SameSite cookie-based session architecture.

**Required action:** Replace persistent refresh-token storage in `localStorage` with a browser session design that does not expose the refresh token to arbitrary page JavaScript, or document and formally accept the residual risk before production release. Add a regression test proving the selected session policy.

**Production gate impact:** Must be resolved or explicitly accepted by the production security owner before production release.

### S-02 — No explicit Content-Security-Policy/security-header contract in repository

**Severity:** Medium  
**Area:** Browser hardening  
**Status:** Open

`index.html` contains standard metadata but no repository-level Content-Security-Policy or other explicit security-header contract. A Cloudflare Worker/deployment layer may supply headers, but this review did not verify an active production header configuration.

**Required action:** Establish and verify a production security-header policy, including CSP appropriate to the deployed application, frame restrictions, content-type sniffing protection, and referrer policy. Record the verified deployment configuration.

**Production gate impact:** Verify before production exposure.

### S-03 — Environment label is hard-coded to STAGING in the application shell

**Severity:** Medium  
**Area:** Environment integrity / operator safety  
**Status:** Open

`App.tsx` renders `STAGING` as a literal environment label. If the same build is deployed to production without an environment-specific value, the UI can misrepresent the active environment to operators.

**Required action:** Derive the displayed environment from controlled deployment configuration and verify staging/production labels independently.

**Production gate impact:** Must be corrected before production operations to reduce operator-targeting risk.

### S-04 — CI lacks an explicit dependency vulnerability/SAST gate

**Severity:** Medium  
**Area:** Supply-chain security  
**Status:** Open

The standard CI quality job runs `npm ci`, lint, typecheck, tests, and build, but the reviewed workflow does not contain an explicit dependency vulnerability audit or SAST/security scanning step.

**Required action:** Add a deterministic, non-blocking or blocking security scan according to the production security policy, with an explicit vulnerability threshold and evidence retention. Avoid introducing an uncontrolled third-party dependency merely for scanning.

**Production gate impact:** Required for a complete security-control baseline or formally deferred with owner/date.

### S-05 — Full runtime RLS negative/positive verification remains a separate hardening milestone

**Severity:** Medium / verification gap  
**Area:** Database authorization  
**Status:** Scheduled — P14-T208

The repository migrations establish RLS, role-based policies, and SELECT-only direct grants, and the CI suite includes authorization-related tests. However, the milestone plan explicitly separates the full RLS negative/positive test suite into P14-T208. Therefore this review does not treat the database authorization model as fully runtime-verified until that milestone completes.

**Required action:** Execute P14-T208 against the supported staging configuration and retain positive/negative evidence for each role and protected surface.

### S-06 — External deployment/control-plane security configuration not fully evidenced in repository review

**Severity:** Low / verification gap  
**Area:** Cloudflare/Supabase control plane  
**Status:** Open verification item

The repository documents the intended separation of GitHub, Cloudflare, Supabase, local, staging, and production responsibilities. This review cannot independently prove current dashboard-level settings such as production secret values, Cloudflare security headers, Supabase Auth policy configuration, database network controls, or platform-level audit retention.

**Required action:** Perform the environment-level verification as part of the production-readiness checklist without exposing secret values in repository artifacts.

## 4. Security-positive observations

1. No service-role key or private key is referenced by the browser authentication module.
2. The browser uses a publishable Supabase key rather than a privileged database credential.
3. Direct database writes are intentionally withheld from the authenticated browser role in the foundation migration.
4. RLS is enabled across the core business tables.
5. The privileged role lookup function has a fixed search path and restricted execution grant.
6. Admin-only surfaces are explicitly separated from ordinary operational reads.
7. Historical import data has explicit admin-only read policies.
8. State-changing commands use bearer authentication and idempotency boundaries.
9. Reporting views are security-invoker and read-only from the application perspective.
10. Export code is constrained to authoritative report/order fields and does not invent financial calculations.
11. Environment documentation explicitly prohibits committing production secrets.

## 5. Gate assessment

**P14-T207 status:** Review executed; findings recorded.  
**Overall security gate:** **Not yet clear for production.**

The repository has substantial security foundations, but the open findings above mean this milestone should not be interpreted as a production-security approval. In particular, the browser refresh-token design, explicit security-header verification, environment-label integrity, and complete RLS runtime verification require closure or formal risk acceptance before production release.

## 6. Required follow-up milestones

The next planned hardening sequence includes:

- **P14-T208:** Full RLS negative/positive test suite
- **P14-T209:** Concurrency tests
- **P14-T210:** Load-test Orders workspace
- **P14-T211:** Load-test bulk scanning/dispatch
- **P14-T212:** Load-test RTO workflows
- **P14-T213:** Query-plan review
- **P14-T214:** Index verification
- **P14-T215:** Structured logs
- **P14-T216:** Error reporting
- **P14-T217:** Request/correlation IDs
- **P14-T218:** Basic performance metrics
- **P14-T219:** Operational alerting path
- **P14-T220:** Deployment/rollback runbook
- **P14-T221:** Incident/data recovery runbook
- **P14-T222:** Production Supabase plan selection
- **P14-T223:** Logical exports
- **P14-T224:** Off-site backups
- **P14-T225:** Restore test
- **P14-T226:** RPO/RTO documentation

## 7. Evidence boundary

This document is a repository-level security review artifact. It records what was verified from version-controlled implementation and what remains an environment-level or later-milestone verification requirement. It intentionally does not claim that unperformed dynamic penetration testing, platform configuration review, or credential testing occurred.
