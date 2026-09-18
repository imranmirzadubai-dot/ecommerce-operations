-- P10-T152 supplemental boundary marker.
begin;
select plan(1);
select ok(to_regprocedure('public.record_delivery_outcome(uuid,text,text,text)') is not null,'T152 delivery outcome command is present');
select * from finish();
rollback;
