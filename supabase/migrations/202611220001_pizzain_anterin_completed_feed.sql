begin;

create or replace function public.sync_pizzain_anterin_feed(p_driver_id text, p_revision text)
returns jsonb language sql stable security definer set search_path = '' as $$
  with completed as (
    select jsonb_build_object(
      'id', o.id, 'merchant', 'pizzain', 'order_number', o.order_number,
      'customer_name', o.customer_name, 'customer_order_type', o.customer_order_type,
      'customer_order_status', o.customer_order_status, 'status', o.status,
      'driver_id', o.driver_id, 'payment_status', o.payment_status,
      'payment_provider', o.payment_provider, 'delivery_fee', o.delivery_fee,
      'subtotal', o.subtotal, 'grand_total', o.grand_total,
      'created_at', o.created_at, 'updated_at', o.updated_at,
      'confirmed_at', o.confirmed_at, 'ready_at', o.ready_at, 'completed_at', o.completed_at,
      'delivery_distance_meters', o.delivery_distance_meters
    ) as item
    from public.pizzain_anterin_orders a
    join public.orders o on o.id = a.order_id
    where nullif(btrim(p_driver_id), '') is not null
      and o.driver_id = p_driver_id
      and o.customer_order_type = 'DELIVERY'
      and o.customer_order_status = 'COMPLETED'
      and o.cancelled_at is null
      and o.status::text not in ('Batal', 'Dibatalkan')
      and o.payment_status::text = 'Lunas'
      and coalesce(o.completed_at, o.updated_at) >= statement_timestamp() - interval '366 days'
    order by coalesce(o.completed_at, o.updated_at) desc, o.id
    limit 100
  ), snapshot_items as (
    select item from public.pizzain_anterin_feed(p_driver_id) item
    union all
    select item from completed
  ), snapshot as (
    select coalesce(jsonb_agg(item order by item->>'id'), '[]'::jsonb) as orders
    from snapshot_items
  ), versioned as (
    select orders, encode(sha256(convert_to(orders::text, 'UTF8')), 'hex') as revision
    from snapshot
  )
  select case when revision = p_revision then jsonb_build_object('revision', revision)
    else jsonb_build_object('revision', revision, 'orders', orders) end
  from versioned;
$$;

revoke all on function public.sync_pizzain_anterin_feed(text, text) from public, anon, authenticated;
grant execute on function public.sync_pizzain_anterin_feed(text, text) to service_role;

commit;
