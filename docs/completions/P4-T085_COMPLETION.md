# P4-T085 — Sales Permissions Completion

**Task:** P4-T085 — Test Sales permissions  
**Phase:** 4 — Auth & Administration  
**Gate:** Access Gate  
**Completion date:** 2026-09-12  
**TCR:** `ECO-TCR-P4-T085-20260912-23aa5cb7`

## Outcome

Added a dedicated Sales-permission regression suite confirming that the locked Sales role is included in the protected operational command boundary and that browser access remains SELECT-only at the table privilege layer.

The tested command boundary includes:

- `create_order`
- `confirm_order`
- `cancel_order`
- `cancel_parcel`

The suite also confirms that the administrative profile-link command remains behind the authenticated boundary and that anonymous callers cannot execute it.

No new business permission was invented in T085. The existing role matrix established by the command layer is exercised; narrower role-specific distinctions remain for T086–T089.

## Evidence

- Dedicated test: `supabase/tests/database/033_sales_permissions.sql`
- Implementation/test commit: `23aa5cb709ba0f72eccaadaad1020a79d5fe968e`
- GitHub Actions run **385 / 34700511356** passed application lint, typecheck, unit tests, build, fresh local Supabase startup, database reset, and rebuild verification.

## Scope boundary

T085 is a permission regression test milestone. It does not alter production configuration, production data, or introduce direct browser write privileges. The broader legacy pgTAP suite remains outside this milestone and is not claimed green.
