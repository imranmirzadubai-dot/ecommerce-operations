-- P12-T195: retain authoritative source batch/row lineage for historical imports.
-- T194 already records lineage in the immutable Historical Import event metadata.
-- This migration hardens that metadata into relational, durable order lineage and
-- marks the corresponding staged row as Imported. No parcel allocation is added.

alter table public.orders
  add column if not exists historical_import_batch_id uuid,
  add column if not exists historical_import_source_row_number integer,
  add column if not exists historical_import_source_record_id text,
  add column if not exists historical_import_source_identity text;

alter table public.orders
  drop constraint if exists orders_historical_import_lineage_check;
alter table public.orders
  add constraint orders_historical_import_lineage_check
  check (
    (historical_import_batch_id is null
      and historical_import_source_row_number is null
      and historical_import_source_record_id is null
      and historical_import_source_identity is null)
    or
    (historical_import_batch_id is not null
      and historical_import_source_row_number is not null
      and historical_import_source_row_number > 0
      and historical_import_source_identity is not null
      and btrim(historical_import_source_identity) <> '')
  );

alter table public.orders
  drop constraint if exists orders_historical_import_batch_fk;
alter table public.orders
  add constraint orders_historical_import_batch_fk
  foreign key (historical_import_batch_id)
  references public.import_batches(id)
  on delete restrict;

create unique index if not exists uq_orders_historical_import_batch_row
  on public.orders(historical_import_batch_id, historical_import_source_row_number)
  where historical_import_batch_id is not null;

create index if not exists idx_orders_historical_import_source_identity
  on public.orders(historical_import_source_identity)
  where historical_import_source_identity is not null;

create or replace function public.retain_historical_import_lineage()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch_id uuid;
  v_source_row_number integer;
  v_source_record_id text;
  v_source_identity text;
  v_existing_batch_id uuid;
  v_existing_row_number integer;
  v_existing_record_id text;
  v_existing_identity text;
  v_row_batch_id uuid;
  v_row_record_id text;
  v_row_identity text;
begin
  if NEW.event_type <> 'Historical Import' then
    return NEW;
  end if;

  if NEW.metadata is null or jsonb_typeof(NEW.metadata) <> 'object' then
    raise exception using errcode='22023', message='Historical Import event metadata must be a JSON object';
  end if;

  begin
    v_batch_id := (NEW.metadata->>'batch_id')::uuid;
    v_source_row_number := (NEW.metadata->>'source_row_number')::integer;
  exception when others then
    raise exception using errcode='22023', message='Historical Import event requires valid batch_id and source_row_number';
  end;

  v_source_record_id := nullif(btrim(NEW.metadata->>'source_record_id'), '');
  v_source_identity := nullif(btrim(NEW.metadata->>'source_identity'), '');

  if v_batch_id is null or v_source_row_number is null or v_source_row_number <= 0
     or v_source_identity is null then
    raise exception using errcode='22023', message='Historical Import event requires batch, positive source row, and source identity lineage';
  end if;

  select r.batch_id, nullif(btrim(r.source_record_id), ''), nullif(btrim(r.source_identity), '')
    into v_row_batch_id, v_row_record_id, v_row_identity
  from public.import_rows r
  where r.batch_id = v_batch_id
    and r.source_row_number = v_source_row_number;

  if not found then
    raise exception using errcode='23503', message='Historical Import lineage references a missing source row';
  end if;

  if v_row_batch_id <> v_batch_id
     or v_row_record_id is distinct from v_source_record_id
     or v_row_identity is distinct from v_source_identity then
    raise exception using errcode='23514', message='Historical Import lineage does not match the retained source row';
  end if;

  select o.historical_import_batch_id,
         o.historical_import_source_row_number,
         o.historical_import_source_record_id,
         o.historical_import_source_identity
    into v_existing_batch_id, v_existing_row_number, v_existing_record_id, v_existing_identity
  from public.orders o
  where o.id = NEW.order_id;

  if v_existing_batch_id is not null then
    if v_existing_batch_id is distinct from v_batch_id
       or v_existing_row_number is distinct from v_source_row_number
       or v_existing_record_id is distinct from v_source_record_id
       or v_existing_identity is distinct from v_source_identity then
      raise exception using errcode='23514', message='Order already has conflicting historical import lineage';
    end if;
    return NEW;
  end if;

  update public.orders
  set historical_import_batch_id = v_batch_id,
      historical_import_source_row_number = v_source_row_number,
      historical_import_source_record_id = v_source_record_id,
      historical_import_source_identity = v_source_identity
  where id = NEW.order_id;

  update public.import_rows
  set status = 'Imported'
  where batch_id = v_batch_id
    and source_row_number = v_source_row_number
    and source_identity = v_source_identity
    and source_record_id is not distinct from v_source_record_id;

  if not found then
    raise exception using errcode='23514', message='Historical Import source row could not be marked Imported';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_retain_historical_import_lineage on public.order_events;
create trigger trg_retain_historical_import_lineage
after insert on public.order_events
for each row
execute function public.retain_historical_import_lineage();

revoke all on function public.retain_historical_import_lineage() from public, anon, authenticated;
