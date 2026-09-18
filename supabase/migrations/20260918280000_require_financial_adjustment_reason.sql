begin;

-- P11-T179: financial adjustments must always carry a meaningful reason.
-- The reason is part of the immutable financial audit trail and must be enforced
-- at the database boundary, not only by caller-side validation.
alter table public.financial_adjustments
  add constraint financial_adjustments_reason_required
  check (btrim(reason) <> '' and length(reason) <= 500);

commit;
