begin;

-- Repository verification test for T062. Execute against a fixture-enabled staging DB.
select has_table_privilege('authenticated', 'public.financial_adjustments', 'SELECT') as authenticated_select;
select not has_table_privilege('authenticated', 'public.financial_adjustments', 'INSERT') as authenticated_insert_denied;
select not has_table_privilege('authenticated', 'public.financial_adjustments', 'UPDATE') as authenticated_update_denied;
select not has_table_privilege('authenticated', 'public.financial_adjustments', 'DELETE') as authenticated_delete_denied;
select exists (
  select 1 from pg_trigger
  where tgrelid = 'public.financial_adjustments'::regclass
    and tgname = 'trg_financial_adjustments_immutable'
) as immutable_trigger;
select exists (
  select 1 from pg_constraint
  where conrelid = 'public.financial_adjustments'::regclass
    and conname = 'financial_adjustments_delta_amount_precision'
) as precision_constraint;

rollback;
