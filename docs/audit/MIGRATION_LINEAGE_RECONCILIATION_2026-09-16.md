# Migration Lineage Reconciliation — 2026-09-16

## Status
**Outcome verification complete; historical filename mismatch is not treated as implementation failure. Production migration remediation remains intentionally blocked until a reproducible forward deployment path is established.**

## Audit rule
A historical migration ID/name does **not** have to match a current repository filename to prove that engineering work was completed. The audit evaluates the resulting implementation and its development evidence: database objects/state, current source code, tests/CI, and Git history. A migration may have been renamed, consolidated, superseded, squashed, or replaced by later migrations.

## Verified staging state

- Production/main repository head at audit time: `213b088255dd3feb3632ae9c810af334ec2db8fe`.
- Staging Supabase project: `mijbpvgxrxjaalimyqgm`.
- Staging migration history contains **33 applied migration IDs**, with first `20260910212711` and last `20260912040049`.
- Current staging contains **18 public application tables, 142 public columns, 95 public constraints, 66 public indexes, 17 RLS policies, and 6 non-internal triggers**.
- Staging contains the implemented database foundations visible in the current schema, including orders/order_items, parcels/parcel_items, customers, shippers, profiles, delivery_outcomes, COD/financial tables, import tables, immutable event/audit structures, and command idempotency.
- Staging contains authoritative database functions including `create_order`, `confirm_order`, `cancel_order`, `cancel_parcel`, `claim_command_idempotency`, `complete_command_idempotency`, `normalize_phone`, `resolve_customer_by_phone`, and `app_role`.
- Staging indexes include uniqueness and integrity boundaries such as customer normalized-phone uniqueness, order number uniqueness, parcel barcode/parcel-number/tracking-ID uniqueness, order-item line uniqueness, COD receipt uniqueness, and command-idempotency uniqueness.
- Current repository contains the corresponding development migration/code/test evidence for the implemented baseline, even where filenames differ from historical staging IDs. For example, the current repository includes `20260910212711_database_foundation_v4.sql`, transactional-command/idempotency migrations, parcel/allocation migrations, delivery-outcome immutability, COD/financial hardening, profile/role hardening, RLS implementation, grants/security-definer hardening, and subsequent order/parcel/invoice work.
- Searches of the current repository for representative historical staging IDs such as `20260910222428` and `20260911003036` do not locate corresponding files.

## Finding

The staging migration ledger and current repository migration directory are **not a one-to-one lineage**. This is a historical bookkeeping/lineage mismatch, not evidence that the underlying engineering work was not done.

The actual implementation must be judged from the resulting schema and development proof. The current staging schema demonstrates that substantial baseline work exists. Where a specific historical requirement is represented by current code/database objects/tests, it can be considered implemented even if its original migration filename is unavailable.

The remaining issue is narrower: the current repository's later migration files extend beyond the staging ledger's last recorded migration. Therefore, **we still cannot assume that every current repository migration is already present in staging**, and we must not blindly replay the whole current directory against a live database.

## Evidence classification

For each historical milestone or migration-derived requirement, classify it as:

1. **Verified implemented** — resulting database object/state plus development evidence establish the functionality; historical migration filename may differ or be absent.
2. **Implemented, historical lineage unresolved** — functionality is demonstrably present, but the exact historical migration that introduced it cannot be reconstructed from currently accessible artifacts.
3. **Not verified** — the claimed implementation cannot be established from database state and development evidence.

A filename mismatch alone never moves an item into category 3.

## Safe deployment implication

The audit does **not** require recovering all 33 original SQL files merely to prove that the work was completed. However, before production deployment we still need a reproducible way to take the **current staging state** to the **current canonical repository state**.

That can be achieved by:

1. Treating the verified staging schema as the starting state rather than trying to recreate its historical filenames.
2. Comparing current staging schema objects against the current repository's intended schema.
3. Identifying which current repository migrations represent changes already present in staging versus genuinely new forward changes.
4. Building a clean disposable database from a documented baseline and applying only the required forward migrations.
5. Running the complete database/quality test suite against that clean reconstruction.
6. Only then preparing the production migration plan.

## Explicit non-actions

- No staging reset was performed.
- No production DDL was executed.
- No attempt was made to mark unmatched historical migration IDs as applied.
- No current migration was renamed merely to match a historical ID.
- No destructive schema reconciliation was performed.

## Decision gate

**Historical migration-ID mismatch is no longer considered a blocker to proving implementation.**

**Production deployment remains gated only by establishing and testing the reproducible forward migration path from the verified staging schema to the current canonical repository state.**
