-- P15-T230 regression fix: PostgreSQL has no built-in min(uuid) aggregate.
-- Invoice historical snapshot capture must select the single parcel UUID without
-- relying on an aggregate that does not exist for uuid.

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

  select count(*) into v_parcel_count
  from public.parcels p
  where p.order_id = new.order_id;

  if v_parcel_count <> 1 then
    raise exception 'Invoice generation requires exactly one parcel for the order';
  end if;

  select p.id into v_parcel_id
  from public.parcels p
  where p.order_id = new.order_id
  order by p.id
  limit 1;

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
