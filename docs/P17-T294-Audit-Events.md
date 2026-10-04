# P17-T294 — Audit Events

## Scope

Provide a trusted, bounded Admin-only read path for the existing `public.audit_logs` source of truth used by privileged User Management operations.

## Audit source of truth

- `public.audit_logs` remains the canonical application audit table.
- Existing P17 lifecycle commands record privileged before/after state where applicable.
- Audit records are transactional with the protected operation: a failed mutation or audit write rolls back the transaction.
- No second audit store is introduced.

## Read contract

`public.admin_list_audit_events(...)` is a `SECURITY DEFINER` read-only function with a pinned `search_path`.

It requires the caller to be authenticated and have the current active `admin` application role.

Supported bounded filters:

- page and page size (maximum 100 rows per request)
- exact action
- exact entity type
- exact entity UUID

The result contains only the audit record fields needed by an Admin audit view:

- audit event UUID
- actor UUID
- action
- entity type / entity UUID
- before/after JSON state
- request ID
- occurrence timestamp
- total result count for pagination

## Security

- Existing RLS policies are unchanged.
- Browser clients do not receive direct write access to `audit_logs`.
- The function is not executable by `public`; execution is granted only to `authenticated` and is still guarded by the active Admin role check.
- No service-role or Supabase secret is exposed.
- Pagination is bounded to prevent unbounded audit-table reads.
- Ordering is deterministic by `occurred_at` and `id`.

## UX boundary

This task establishes the trusted data/API boundary. Admin audit presentation and navigation remain in the later P17 UX tasks.

## Production safety

T294 changes GitHub source only. It does not mutate production. Staging migration and verification remain later P17 deployment gates.
