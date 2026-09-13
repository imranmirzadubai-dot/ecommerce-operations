-- P3-T072: least-privilege grant verification.
-- These checks are executable as catalog/privilege assertions in staging.
select has_table_privilege('anon','public.orders','insert') = false as anon_table_write_denied;
select has_table_privilege('authenticated','public.orders','insert') = false as authenticated_table_write_denied;
select has_table_privilege('authenticated','public.orders','select') = true as authenticated_select_allowed;
select has_table_privilege('authenticated','public.financial_adjustments','update') = false as financial_update_denied;
select has_sequence_privilege('authenticated','public.order_number_seq','usage') = false as sequence_usage_denied;
select has_function_privilege('anon','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute') = false as anon_command_denied;
select has_function_privilege('authenticated','public.create_order(text,text,text,text,numeric,jsonb,text,text)','execute') = true as authenticated_command_allowed;
