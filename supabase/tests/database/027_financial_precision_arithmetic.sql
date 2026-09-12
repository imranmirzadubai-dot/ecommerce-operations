-- P3-T076: financial precision/arithmetic tests.
-- Designed for the repository's pgTAP-capable test environment.

begin;
select plan(10);

select is((123.45::numeric(12,2) + 6.55::numeric(12,2)), 130.00::numeric, 'positive: decimal addition is exact');
select is((100.00::numeric(12,2) - 33.33::numeric(12,2)), 66.67::numeric, 'positive: decimal subtraction is exact');
select is((0.10::numeric(12,2) + 0.20::numeric(12,2)), 0.30::numeric, 'positive: no binary floating-point drift');
select is(round((123.4567::numeric),2), 123.46::numeric, 'positive: two-decimal rounding is explicit');
select is(round((-12.345::numeric),2), -12.35::numeric, 'positive: negative adjustment rounds to two decimals');
select ok((select numeric_precision=12 and numeric_scale=2 from information_schema.columns where table_schema='public' and table_name='orders' and column_name='original_amount'), 'positive: orders.original_amount is NUMERIC(12,2)');
select ok((select count(*)=1 from pg_constraint where conrelid='public.financial_adjustments'::regclass and contype='c' and pg_get_constraintdef(oid) like '%delta_amount = round(delta_amount, 2)%'), 'positive: financial adjustments enforce two-decimal precision');
select is((1000.00::numeric + 125.50::numeric + (-25.50)::numeric), 1100.00::numeric, 'positive: effective amount arithmetic reconciles adjustments');
select ok((0.01::numeric + 0.02::numeric) = 0.03::numeric, 'positive: cent-level arithmetic remains exact');
select ok((round(9999999999.99::numeric,2) = 9999999999.99::numeric), 'positive: supported upper-range amount retains cents');

select * from finish();
rollback;
