# P6-T110 — Order Export

## Status
Complete.

## Implementation
The Orders Workspace now provides an **Export CSV** action for the currently loaded, filtered page of orders. The export is Excel-compatible CSV and includes order number, customer, phone, lifecycle state, amount (AED), order date, and item details. CSV cells are escaped and the file includes a UTF-8 BOM for spreadsheet compatibility.

## Evidence
- Commit: `37bdb6fb23f649526efb1e792992d756918f06c2`
- GitHub Actions CI: `#574` / run `34728694641` — PASS
- Local Supabase database tests — PASS
- Lint — PASS
- Typecheck — PASS
- Unit tests — PASS
- Build — PASS

## Scope note
The export is intentionally limited to the orders currently loaded in the Orders Workspace page and respects the active server-side search/filter/date result set. No production data was used or modified.

## TCR
`ECO-TCR-P6-T110-20260913-37bdb6fb`
