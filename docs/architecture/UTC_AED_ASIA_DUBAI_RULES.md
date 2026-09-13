# UTC / AED / Asia-Dubai Rules — T048

## 1. Purpose

This document freezes the MVP timezone, date-boundary, and currency contract for the UAE e-commerce operations application.

## 2. Time storage

- All authoritative timestamps are stored as PostgreSQL `timestamptz` values.
- The application treats persisted timestamps as instants in time, not as local wall-clock strings.
- New database/application code must not store business event times as timezone-less `timestamp` values when the value represents an instant.
- UTC is the canonical transport/storage representation. Clients must not reinterpret an instant using the browser's local timezone for business logic.

## 3. UAE business timezone

- The authoritative business timezone for operational display and business date boundaries is `Asia/Dubai`.
- `Asia/Dubai` is UTC+04:00 and has no daylight-saving transition.
- Operational screens may display timestamps in UAE local time, while preserving the underlying instant.
- API contracts should return timezone-aware timestamps/ISO-8601 values; the client must render them according to the business display policy.

## 4. Date boundaries

For any report, daily filter, operational date, or reconciliation grouped by business date:

`business_date = calendar date of instant converted to Asia/Dubai`.

Therefore a UTC timestamp near midnight must not be grouped by UTC calendar date when the requested business date is UAE-local.

Date ranges supplied as UAE business dates are interpreted using `Asia/Dubai` midnight boundaries, then converted to instants for database querying.

Example rule:

- requested business day `2026-09-12` begins at `2026-09-12 00:00 Asia/Dubai`;
- it ends immediately before `2026-09-13 00:00 Asia/Dubai`;
- database queries use the corresponding timezone-aware instants.

## 5. Audit and event timestamps

`order_events`, `audit_logs`, financial evidence, COD receipts, delivery outcomes, and import lifecycle timestamps represent actual instants and are stored with timezone information. Displaying them in UAE time must not change the stored instant.

Ordering of events is by authoritative timestamp plus deterministic secondary ordering where two records share the same timestamp; timestamps must never be manually shifted to manufacture ordering.

## 6. Currency

- MVP operating currency is **AED** (United Arab Emirates dirham).
- Monetary amounts are stored as exact numeric values, not floating-point application values.
- Currency must be explicit in money-bearing domain/API contracts where the entity can reasonably become multi-currency later.
- MVP workflows accept AED only unless a later approved architecture change introduces another currency.
- The application must not silently convert currencies.
- No exchange-rate logic is required for the AED-only MVP.

## 7. Money arithmetic

- Financial calculations are performed server-side using exact decimal arithmetic.
- Currency rounding/scale must follow the financial contract already established for the relevant amount.
- The UI is presentation only and cannot be the authoritative source for monetary totals.
- Persisted amounts and adjustments must preserve the precision required by the financial contract; binary floating-point arithmetic is prohibited for authoritative money calculations.

## 8. Currency display

- Default user-facing currency display is AED.
- Amounts should be labeled unambiguously, e.g. `AED 125.00`, rather than relying on a symbol alone.
- Display formatting may vary by UI locale, but the underlying currency remains AED and the stored numeric value is unchanged.

## 9. API and frontend rules

- API request/response timestamps are timezone-aware ISO-8601 values.
- API date filters that mean business dates are explicitly documented as UAE business dates.
- Frontend date libraries must not silently substitute the user's machine timezone for `Asia/Dubai` business-date calculations.
- Browser locale may affect presentation formatting only, never business-date interpretation or money arithmetic.

## 10. Reports and exports

Reports and exports that use daily/weekly/monthly operational periods use `Asia/Dubai` boundaries unless the report definition explicitly specifies another business calendar.

Generated export rows retain authoritative timestamps; where a local business date is shown, it is derived from `Asia/Dubai`.

## 11. Historical data

Imported historical timestamps must retain their source meaning. If a source provides a timezone-aware instant, preserve it. If a source provides only a local wall-clock timestamp, the import contract must identify the source timezone before converting it to an authoritative instant; do not guess based only on the server/browser timezone.

If source timezone cannot be established, the row remains a validation/reconciliation issue rather than silently receiving a timezone.

## 12. Non-negotiable rules

1. Store authoritative instants as `timestamptz`.
2. Use `Asia/Dubai` for UAE business-date boundaries.
3. Never use browser local timezone for business logic.
4. Never silently convert currencies.
5. MVP currency is AED.
6. Use exact decimal arithmetic for authoritative money.
7. Preserve source timezone semantics during historical import.
8. Do not infer missing source timezone.

## 13. Phase 3 implementation requirements

Translate this contract into database/API/UI tests covering:

- UTC-to-Dubai boundary grouping;
- midnight and month/year boundary filters;
- timestamp round trips without instant drift;
- browser timezone independence;
- DST-proof behavior for `Asia/Dubai`;
- AED-only validation;
- currency-code preservation;
- exact money arithmetic and rounding;
- export/report business-date boundaries;
- historical import timezone validation.

## 14. T048 decision

**FORMALIZED — UTC storage, Asia/Dubai business timezone, and AED currency rules are frozen for the MVP.**

No production or staging data was changed by this architecture task.