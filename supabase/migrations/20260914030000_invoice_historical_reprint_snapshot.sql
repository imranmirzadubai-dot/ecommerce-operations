-- E-Commerce Operations MVP P8-T132
-- Historical invoice reprint consistency.
-- Source: locked Master Implementation Plan v4.0, Invoice and Printing Contract.
--
-- An invoice reprint must render from the immutable business snapshot captured
-- when the invoice record was generated, not from mutable live order/customer
-- data. The snapshot is immutable and retains the template version lineage.

alter table public.invoice_records
  add column if not exists source_snapshot jsonb;

-- Existing invoice records are backfilled from their current authoritative
-- source before the new invariant becomes mandatory. If an order does not
-- have exactly one parcel or otherwise lacks required invoice data, fail
-- rather than inventing or silently degrading historical values.
do $$
begin
  if exists (
    select 1
    from public.invoice_records ir
    join public.orders o on o.id = ir.order_id
    left join public.customers c on c.id = o.customer_id
    left join lateral (
      select count(*)::integer as parcel_count
      from public.parcels p
      where p.order_id = o.id
    ) pc on true
    where ir.source_snapshot is null
      and (c.id is null or pc.parcel_count <> 1)
  ) then
    raise exception 'Cannot create historical invoice snapshots: an invoice order must have exactly one parcel and customer';
  end if;
end;
$$;

update public.invoice_records ir
set source_snapshot = jsonb_build_object(
  'invoiceNumber', ir.invoice_number,
  'orderNumber', o.order_number,
  'parcelNumber', p.parcel_number,
  'templateVersion', ir.template_version,
  'generatedAt', ir.generated_at,
  'orderDate', o.order_date,
  'currencyCode', o.currency_code,
  'originalAmount', o.original_amount,
  'customer', jsonb_build_object(
    'name', c.name,
    'phone', c.phone,
    'address', c.address,
    'city', c.city
  ),
  'items', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'lineNo', oi.line_no,
        'description', oi.description,
        'quantity', oi.quantity
      )
      order by oi.line_no
    )
    from public.order_items oi
    where oi.order_id = o.id
  ), '[]'::jsonb),
  'trackingId', p.tracking_id
)
from public.orders o
join public.customers c on c.id = o.customer_id
join lateral (
  select p.parcel_number, p.tracking_id
  from public.parcels p
  where p.order_id = o.id
  order by p.created_at, p.id
  limit 1
) p on true
where ir.order_id = o.id
  and ir.source_snapshot is null;

alter table public.invoice_records
  alter column source_snapshot set not null;

alter table public.invoice_records
  drop constraint if exists invoice_records_source_snapshot_object_check;

alter table public.invoice_records
  add constraint invoice_records_source_snapshot_object_check
  check (jsonb_typeof(source_snapshot) = 'object');

create or replace function public.prevent_invoice_record_historical_snapshot_mutation()
returns trigger
language plpgsql
as $$
begin
  if new.source_snapshot is distinct from old.source_snapshot then
    raise exception 'Invoice historical snapshot is immutable';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_invoice_record_historical_snapshot_mutation() from public;

drop trigger if exists trg_invoice_record_historical_snapshot_immutable
  on public.invoice_records;

create trigger trg_invoice_record_historical_snapshot_immutable
before update on public.invoice_records
for each row
execute function public.prevent_invoice_record_historical_snapshot_mutation();

-- New invoice records receive their snapshot atomically at generation.
-- The trigger derives the snapshot from the order/customer/items/parcel state
-- at insert time. No later business-data mutation can rewrite it.
create or replace function public.capture_invoice_historical_snapshot()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order public.orders%rowtype;
  v_customer public.customers%rowtype;
  v_parcel public.parcels%rowtype;
  v_parcel_id uuid;
  v_parcel_count integer;
  v_item_count integer;
begin
  select * into v_order
  from public.orders
  where id = new.order_id;

  if not found then
    raise exception 'Invoice order source not found';
  end if;

  select * into v_customer
  from public.customers
  where id = v_order.customer_id;

  if not found then
    raise exception 'Invoice customer source not found';
  end if;

  select count(*), min(p.id)
    into v_parcel_count, v_parcel_id
  from public.parcels p
  where p.order_id = new.order_id;

  if v_parcel_count <> 1 then
    raise exception 'Invoice generation requires exactly one parcel for the order';
  end if;

  select * into v_parcel
  from public.parcels
  where id = v_parcel_id;

  select count(*) into v_item_count
  from public.order_items
  where order_id = new.order_id;

  if v_item_count = 0 then
    raise exception 'Invoice generation requires at least one order item';
  end if;

  new.source_snapshot := jsonb_build_object(
    'invoiceNumber', new.invoice_number,
    'orderNumber', v_order.order_number,
    'parcelNumber', v_parcel.parcel_number,
    'templateVersion', new.template_version,
    'generatedAt', new.generated_at,
    'orderDate', v_order.order_date,
    'currencyCode', v_order.currency_code,
    'originalAmount', v_order.original_amount,
    'customer', jsonb_build_object(
      'name', v_customer.name,
      'phone', v_customer.phone,
      'address', v_customer.address,
      'city', v_customer.city
    ),
    'items', (
      select jsonb_agg(
        jsonb_build_object(
          'lineNo', oi.line_no,
          'description', oi.description,
          'quantity', oi.quantity
        )
        order by oi.line_no
      )
      from public.order_items oi
      where oi.order_id = new.order_id
    ),
    'trackingId', v_parcel.tracking_id
  );

  return new;
end;
$$;

revoke all on function public.capture_invoice_historical_snapshot() from public;

drop trigger if exists trg_invoice_records_capture_historical_snapshot
  on public.invoice_records;

create trigger trg_invoice_records_capture_historical_snapshot
before insert on public.invoice_records
for each row
execute function public.capture_invoice_historical_snapshot();
