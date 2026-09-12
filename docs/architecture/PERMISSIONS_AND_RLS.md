# Permissions and RLS Contract — v4.0

## Roles

- `sales`
- `operations`
- `admin`

Supabase Auth establishes identity. The protected profile establishes the application role. PostgreSQL RLS and explicit grants are enforced independently of UI checks.

## Role capabilities

| Capability | Sales | Operations | Admin |
|---|---:|---:|---:|
| Customer/order history | Yes | Yes | Yes |
| Create/edit pre-confirmed order | Yes | Yes | Yes |
| Delivery/NDR | Yes | Yes | Yes |
| Eligible cancellation | Yes | Yes | Yes |
| Invoice/COD receipt | Yes | Yes | Yes |
| Shipper assignment | No | Yes | Yes |
| Dispatch | No | Yes | Yes |
| RTO/Lost/Damaged | No | Yes | Yes |
| COD exception resolution | No | No | Yes |
| Financial adjustment | No | No | Yes |
| Historical import | No | No | Yes |
| User/settings administration | No | No | Yes |

Cancellation is deliberately not role-restricted; lifecycle preconditions remain mandatory.

## RLS principles

1. Enable RLS on every application-exposed domain table.
2. Do not rely on hidden UI controls for authorization.
3. Use authenticated identity plus protected application role for policy decisions.
4. Sensitive writes and race-sensitive state changes go through server-side transactional commands.
5. Privileged functions use explicit execute grants and, only where required, `SECURITY DEFINER` with a controlled search path and schema-qualified references.
6. Service-role credentials never reach the browser.
7. Every role receives explicit positive and negative database tests.
8. Audit/event records are append-only to application roles; historical records are not editable/deletable through normal application access.
