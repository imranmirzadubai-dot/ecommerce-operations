-- P10-T163A: system-maintained order lifecycle synchronization.
-- A first dispatched/later parcel activates a Confirmed order. An Active order
-- completes only when every parcel is terminal and any COD obligation is resolved
-- or explicitly closed. The trigger preserves the authoritative order lifecycle
-- state while keeping transition history immutable.

create or replace function public.sync_order_lifecycle_from_parcel()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog, public
as $$
declare
  v_order_state text;
  v_order_number text;
  v_now timestamptz := now();
  v_actor uuid := auth.uid();
  v_all_terminal boolean;
  v_cod_resolved boolean;
begin
  if tg_op <> 'UPDATE' or new.state is not distinct from old.state then
    return new;
  end if;

  select o.lifecycle_state,o.order_number
    into v_order_state,v_order_number
  from public.orders o
  where o.id=new.order_id
  for update;

  if not found then
    return new;
  end if;

  if v_order_state='Confirmed'
     and new.state in ('Dispatched','In Transit','NDR','Delivered','RTO','Lost','Damaged') then
    update public.orders
    set lifecycle_state='Active',updated_at=v_now
    where id=new.order_id and lifecycle_state='Confirmed';

    insert into public.order_events(order_id,parcel_id,event_type,performed_by,event_time,metadata)
    values(
      new.order_id,new.id,'OrderActivated',v_actor,v_now,
      jsonb_build_object('from','Confirmed','to','Active','trigger_parcel_state',new.state,'parcel_number',new.parcel_number)
    );

    insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
    values(
      v_actor,'order_activated','order',new.order_id,
      jsonb_build_object('lifecycle_state','Confirmed'),
      jsonb_build_object('lifecycle_state','Active','trigger_parcel_id',new.id,'trigger_parcel_state',new.state)
    );

    v_order_state:='Active';
  end if;

  if v_order_state='Active' then
    select not exists (
      select 1
      from public.parcels p
      where p.order_id=new.order_id
        and not public.is_terminal_parcel_state(p.state)
    )
    and exists (select 1 from public.parcels p where p.order_id=new.order_id)
    into v_all_terminal;

    select not exists (
      select 1
      from public.cod_obligations c
      where c.order_id=new.order_id
        and c.state not in ('Received','Voided','Closed')
    )
    into v_cod_resolved;

    if v_all_terminal and v_cod_resolved then
      update public.orders
      set lifecycle_state='Completed',updated_at=v_now
      where id=new.order_id and lifecycle_state='Active';

      insert into public.order_events(order_id,parcel_id,event_type,performed_by,event_time,metadata)
      values(
        new.order_id,new.id,'OrderCompleted',v_actor,v_now,
        jsonb_build_object('from','Active','to','Completed','trigger_parcel_state',new.state,'parcel_number',new.parcel_number)
      );

      insert into public.audit_logs(actor,action,entity_type,entity_id,before_data,after_data)
      values(
        v_actor,'order_completed','order',new.order_id,
        jsonb_build_object('lifecycle_state','Active'),
        jsonb_build_object('lifecycle_state','Completed','trigger_parcel_id',new.id,'trigger_parcel_state',new.state)
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_order_lifecycle_from_parcel() from public, anon;
grant execute on function public.sync_order_lifecycle_from_parcel() to authenticated;

drop trigger if exists trg_sync_order_lifecycle_from_parcel on public.parcels;
create trigger trg_sync_order_lifecycle_from_parcel
after update of state on public.parcels
for each row
execute function public.sync_order_lifecycle_from_parcel();

comment on function public.sync_order_lifecycle_from_parcel() is
  'P10-T163A: system-maintained Confirmed→Active and Active→Completed order lifecycle transitions driven by authoritative parcel state changes and resolved COD state.';
