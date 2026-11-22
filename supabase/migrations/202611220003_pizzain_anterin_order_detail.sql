begin;

create or replace function public.record_pizzain_anterin_kitchen_ready()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.pizzain_anterin_orders a where a.order_id = new.id) then
    return new;
  end if;

  if old.ready_at is not null then
    new.ready_at := old.ready_at;
  elsif (
    (new.status::text = 'Selesai' and old.status::text = 'Sedang Disiapkan'
      and new.customer_order_status in ('DRIVER_ASSIGNED', 'PREPARING', 'READY_FOR_PICKUP'))
    or (lower(new.status::text) = 'siap diambil' and lower(old.status::text) is distinct from 'siap diambil')
    or (new.customer_order_status = 'READY_FOR_PICKUP' and old.customer_order_status is distinct from new.customer_order_status)
  ) then
    new.ready_at := coalesce(new.ready_at,
      case when new.completed_at is distinct from old.completed_at then new.completed_at end,
      statement_timestamp());
  end if;
  return new;
end;
$$;

revoke all on function public.record_pizzain_anterin_kitchen_ready() from public, anon, authenticated, service_role;

drop trigger if exists pizzain_anterin_record_kitchen_ready on public.orders;
create trigger pizzain_anterin_record_kitchen_ready
before update of status, customer_order_status, ready_at on public.orders
for each row when (new.customer_order_type = 'DELIVERY')
execute function public.record_pizzain_anterin_kitchen_ready();

create or replace function public.pizzain_anterin_order_detail(p_driver_id text, p_order_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id,
    'customer_phone', o.customer_phone,
    'delivery_address', o.delivery_address,
    'delivery_note', o.delivery_note,
    'delivery_location', o.delivery_location,
    'delivery_latitude', o.delivery_latitude,
    'delivery_longitude', o.delivery_longitude,
    'ready_at', o.ready_at,
    'note', o.note,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_name', i.product_name, 'qty', i.qty, 'price', i.price,
        'discount', i.discount, 'variant_label', i.variant_label, 'note', i.note,
        'addons', coalesce((
          select jsonb_agg(jsonb_build_object('addon_name', a.addon_name, 'qty', a.qty, 'price', a.price) order by a.id)
          from public.order_item_addons a where a.order_item_id = i.id
        ), '[]'::jsonb)
      ) order by i.id)
      from public.order_items i where i.order_id = o.id
    ), '[]'::jsonb)
  )
  from public.pizzain_anterin_orders pilot
  join public.orders o on o.id = pilot.order_id
  where o.id = p_order_id and o.driver_id = p_driver_id and nullif(btrim(p_driver_id), '') is not null
    and o.customer_order_type = 'DELIVERY'
    and o.cancelled_at is null and o.status::text not in ('Batal', 'Dibatalkan')
    and (
      o.customer_order_status in ('DRIVER_ASSIGNED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'DELIVERING')
      or (o.customer_order_status = 'COMPLETED' and o.payment_status::text = 'Lunas'
        and coalesce(o.completed_at, o.updated_at) >= statement_timestamp() - interval '366 days')
    );
$$;

revoke all on function public.pizzain_anterin_order_detail(text, uuid) from public, anon, authenticated;
grant execute on function public.pizzain_anterin_order_detail(text, uuid) to service_role;

commit;
