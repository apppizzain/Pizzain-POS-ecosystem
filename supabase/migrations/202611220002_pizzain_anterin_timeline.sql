begin;

alter table public.orders
  add column if not exists driver_accepted_at timestamptz,
  add column if not exists dispatched_at timestamptz;

create or replace function public.record_pizzain_anterin_timeline()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.driver_id is null or not exists (
    select 1 from public.pizzain_anterin_orders a where a.order_id = new.id
  ) then return new; end if;

  if old.customer_order_status = 'SEARCHING_DRIVER' and new.customer_order_status = 'DRIVER_ASSIGNED' then
    new.driver_accepted_at := statement_timestamp();
  elsif new.customer_order_status = 'DELIVERING' and old.dispatched_at is null then
    new.dispatched_at := statement_timestamp();
  end if;
  return new;
end;
$$;

revoke all on function public.record_pizzain_anterin_timeline() from public, anon, authenticated, service_role;

drop trigger if exists pizzain_anterin_record_timeline on public.orders;
create trigger pizzain_anterin_record_timeline
before update of customer_order_status on public.orders
for each row when (
  new.customer_order_type = 'DELIVERY' and old.customer_order_status is distinct from new.customer_order_status
  and new.customer_order_status in ('DRIVER_ASSIGNED', 'DELIVERING')
)
execute function public.record_pizzain_anterin_timeline();

-- The POS saves the payment row separately from the order's Lunas status.
create or replace function public.notify_pizzain_anterin_payment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_order public.orders;
begin
  if new.paid_at is null then return new; end if;
  if tg_op = 'UPDATE' and new.paid_at is not distinct from old.paid_at then return new; end if;

  select o.* into v_order from public.pizzain_anterin_orders a
  join public.orders o on o.id = a.order_id
  where a.order_id = new.order_id
    and o.customer_order_type = 'DELIVERY' and o.payment_provider = 'courier_cash'
    and o.payment_status::text = 'Lunas' and o.driver_id is not null and o.cancelled_at is null
    and o.status::text not in ('Batal', 'Dibatalkan')
    and o.customer_order_status in ('DRIVER_ASSIGNED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP');

  if found then
    perform public.send_pizzain_anterin_signal(v_order, 'driver_sync', statement_timestamp());
  end if;
  return new;
end;
$$;

revoke all on function public.notify_pizzain_anterin_payment() from public, anon, authenticated, service_role;

drop trigger if exists pizzain_anterin_payment_push on public.payments;
create trigger pizzain_anterin_payment_push
after insert or update of paid_at on public.payments
for each row execute function public.notify_pizzain_anterin_payment();

create or replace function public.pizzain_anterin_feed(p_driver_id text)
returns setof jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id,
    'merchant', 'pizzain',
    'order_number', o.order_number,
    'customer_order_type', o.customer_order_type,
    'customer_order_status', o.customer_order_status,
    'status', o.status,
    'payment_status', o.payment_status,
    'payment_provider', o.payment_provider,
    'subtotal', o.subtotal,
    'grand_total', o.grand_total,
    'delivery_fee', o.delivery_fee,
    'delivery_distance_meters', o.delivery_distance_meters,
    'created_at', o.created_at,
    'updated_at', o.updated_at,
    'ready_at', o.ready_at,
    'confirmed_at', o.confirmed_at,
    'driver_id', o.driver_id
  ) || case when o.driver_id = p_driver_id then jsonb_build_object(
    'driver_accepted_at', o.driver_accepted_at,
    'cashier_paid_at', payment.paid_at,
    'dispatched_at', o.dispatched_at,
    'customer_name', o.customer_name,
    'customer_phone', o.customer_phone,
    'delivery_address', o.delivery_address,
    'delivery_note', o.delivery_note,
    'delivery_latitude', o.delivery_latitude,
    'delivery_longitude', o.delivery_longitude
  ) else '{}'::jsonb end
  from public.pizzain_anterin_orders a
  join public.orders o on o.id = a.order_id
  left join lateral (
    select p.paid_at from public.payments p
    where p.order_id = o.id and p.paid_at is not null
    order by p.paid_at desc limit 1
  ) payment on o.driver_id = p_driver_id and o.payment_provider = 'courier_cash' and o.payment_status::text = 'Lunas'
  where nullif(btrim(p_driver_id), '') is not null
    and o.customer_order_type = 'DELIVERY'
    and o.cancelled_at is null
    and o.status::text not in ('Batal', 'Dibatalkan')
    and (
      (o.customer_order_status = 'SEARCHING_DRIVER' and nullif(o.driver_id, '') is null
        and coalesce(o.updated_at, o.created_at) > statement_timestamp() - interval '5 minutes')
      or (o.driver_id = p_driver_id and o.customer_order_status in
        ('DRIVER_ASSIGNED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'DELIVERING'))
    )
  order by o.updated_at desc nulls last, o.id
  limit 100;
$$;

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
      'delivery_distance_meters', o.delivery_distance_meters,
      'driver_accepted_at', o.driver_accepted_at,
      'cashier_paid_at', payment.paid_at,
      'dispatched_at', o.dispatched_at
    ) as item
    from public.pizzain_anterin_orders a
    join public.orders o on o.id = a.order_id
    left join lateral (
      select p.paid_at from public.payments p
      where p.order_id = o.id and p.paid_at is not null
      order by p.paid_at desc limit 1
    ) payment on o.payment_provider = 'courier_cash' and o.payment_status::text = 'Lunas'
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
