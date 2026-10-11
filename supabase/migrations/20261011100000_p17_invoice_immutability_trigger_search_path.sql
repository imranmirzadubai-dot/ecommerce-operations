begin;

-- Pin name resolution for immutable invoice trigger functions.
-- These trigger functions only raise exceptions, but should not rely on a
-- mutable caller/session search_path.
alter function public.prevent_invoice_template_version_mutation()
  set search_path = pg_catalog, public;

alter function public.prevent_invoice_print_event_mutation()
  set search_path = pg_catalog, public;

commit;
