# Repository Audit Inventory

**As of:** 2026-10-13  
**Repository:** `imranmirzadubai-dot/ecommerce-operations`  
**Baseline commit:** `3a8e88d6d2e3b06a6a09cf911143bba29357da83`

## Counts recorded in read-only inventory

| Area | Recorded count | Notes |
|---|---:|---|
| YAML workflows in `.github/workflows` | 35 | Plus `ecommerce-audit.md` and `ecommerce-audit.lock.yml` in that directory. Count is inventory only. |
| SQL migrations | 146 | Under `supabase/migrations`. |
| Database test SQL files | 161 | Under `supabase/tests/database`. |
| Open pull requests | 28 | Count at inventory time; it can change. |

## CI evidence snapshot

Workflow run [38356571795](https://github.com/imranmirzadubai-dot/ecommerce-operations/actions/runs/38356571795) ran against PR head `9737b7b64b949d7fb8201fa77096627e05ad39ad`, not the baseline main SHA. Recorded results:
- Lint: passed.
- Typecheck: passed.
- Unit tests: 149 passed.
- Build: passed.
- Source graph: passed; 49 source files, no duplicate logical stems or circular imports.
- Isolated database checks: 64 SQL files / 702 tests passed.
- Dependency install: passed, with 9 high-severity npm vulnerability findings reported.

## Links

- [Workflows](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/.github/workflows)
- [Migrations](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/supabase/migrations)
- [Database tests](https://github.com/imranmirzadubai-dot/ecommerce-operations/tree/main/supabase/tests/database)
- [Pull requests](https://github.com/imranmirzadubai-dot/ecommerce-operations/pulls)

Counts should be refreshed before using this inventory for a release or security sign-off. This document does not certify workflow safety, secret absence, backup recoverability, accessibility, performance, or financial concurrency.
