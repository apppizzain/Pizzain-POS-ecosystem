begin;

create function public.owner_delete_delivery_order(p_order_id uuid, p_order_number text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null
    or coalesce(auth.jwt()->>'is_anonymous', 'false') <> 'false'
    or (auth.jwt()->'app_metadata'->>'pizzain_pos_role') is distinct from 'owner' then
    raise exception 'Akun Supabase Owner diperlukan.' using errcode = '42501';
  end if;
  if p_order_id is null or nullif(btrim(p_order_number), '') is null then
    raise exception 'Identitas pesanan tidak lengkap.' using errcode = '22023';
  end if;

  select * into v_order from public.orders
    where id = p_order_id and order_number = p_order_number
    for update;
  if not found then
    return false;
  end if;
  if upper(btrim(coalesce(v_order.type::text, ''))) <> 'DELIVERY'
    and upper(btrim(coalesce(v_order.customer_order_type::text, ''))) <> 'DELIVERY' then
    raise exception 'Pesanan ini bukan Delivery.' using errcode = '22023';
  end if;

  delete from public.pizzain_anterin_outbox where order_id = v_order.id;
  delete from public.pizzain_anterin_orders where order_id = v_order.id;
  delete from public.order_item_addons addon using public.order_items item
    where addon.order_item_id = item.id and item.order_id = v_order.id;
  delete from public.order_items where order_id = v_order.id;
  delete from public.payments where order_id = v_order.id;
  delete from public.orders where id = v_order.id;
  if not found then
    raise exception 'Penghapusan pesanan tidak selesai.' using errcode = 'P0001';
  end if;
  return true;
end;
$$;

revoke all on function public.owner_delete_delivery_order(uuid, text) from public, anon;
grant execute on function public.owner_delete_delivery_order(uuid, text) to authenticated;
notify pgrst, 'reload schema';

commit;
