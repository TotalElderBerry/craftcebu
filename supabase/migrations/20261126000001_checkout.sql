-- Milestone 4: checkout and order fulfilment.
-- Every write to orders goes through these functions, so prices, stock, totals
-- and commission are always computed in the database, never by the browser.

-- Shop orders change only through update_shop_order_status() below; a direct
-- update could otherwise rewrite amounts or skip steps.
drop policy if exists "Artisan updates its own shop orders; owner any" on public.order_shops;

-- Put a shop order's items back into stock (used when it's cancelled).
create or replace function public.restock_order_shop(p_order_shop_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.products p
  set stock = p.stock + oi.qty
  from public.order_items oi
  where oi.order_shop_id = p_order_shop_id and oi.product_id = p.id;
$$;
revoke execute on function public.restock_order_shop(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- place_order: one checkout, split into one order_shops row per artisan.
-- p_items is [{"product_id": "...", "qty": 2}, ...]. Returns the new order id.
-- ---------------------------------------------------------------------------
create or replace function public.place_order(
  p_items jsonb,
  p_address_id uuid,
  p_payment_method public.payment_method
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := auth.uid();
  v_addr public.addresses;
  v_lines jsonb;
  v_problem text;
  v_fee numeric(10, 2);
  v_pct numeric;
  v_order_id uuid;
  v_shop record;
  v_order_shop_id uuid;
  v_total numeric(10, 2) := 0;
begin
  if v_buyer is null then
    raise exception 'Sign in to place an order';
  end if;
  if exists (select 1 from public.profiles where id = v_buyer and is_banned) then
    raise exception 'This account can''t place orders';
  end if;

  select * into v_addr from public.addresses where id = p_address_id and profile_id = v_buyer;
  if not found then
    raise exception 'Choose a delivery address';
  end if;

  -- Merge repeated products into one line each.
  select jsonb_agg(jsonb_build_object('product_id', product_id, 'qty', qty))
  into v_lines
  from (
    select (e ->> 'product_id')::uuid as product_id, sum((e ->> 'qty')::int)::int as qty
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
    group by 1
  ) merged;
  if v_lines is null then
    raise exception 'Your cart is empty';
  end if;

  -- Lock the products so two buyers can't both take the last piece.
  perform 1 from public.products
  where id in (select product_id from jsonb_to_recordset(v_lines) r(product_id uuid, qty int))
  order by id
  for update;

  select case
      when p.id is null then 'An item in your cart is no longer available'
      when r.qty < 1 then 'Quantities must be at least 1'
      when not p.is_active or a.status <> 'verified' then format('%s is no longer available', p.name)
      when a.profile_id = v_buyer then format('%s is from your own shop', p.name)
      when p.stock < r.qty then format('Only %s of %s left', p.stock, p.name)
    end
  into v_problem
  from jsonb_to_recordset(v_lines) r(product_id uuid, qty int)
  left join public.products p on p.id = r.product_id
  left join public.artisans a on a.id = p.artisan_id
  where p.id is null or r.qty < 1 or not p.is_active or a.status <> 'verified'
     or a.profile_id = v_buyer or p.stock < r.qty
  limit 1;
  if v_problem is not null then
    raise exception '%', v_problem;
  end if;

  v_fee := coalesce((select (value #>> '{}')::numeric from public.settings where key = 'shipping_fee_per_shop'), 0);
  v_pct := coalesce((select (value #>> '{}')::numeric from public.settings where key = 'commission_percent'), 0);

  insert into public.orders (buyer_id, ship_recipient, ship_phone, ship_address, total, payment_method)
  values (
    v_buyer,
    v_addr.recipient,
    v_addr.phone,
    concat_ws(', ', v_addr.street, v_addr.barangay, v_addr.city, v_addr.province),
    0,
    p_payment_method
  )
  returning id into v_order_id;

  for v_shop in
    select p.artisan_id, sum(p.price * r.qty) as subtotal
    from jsonb_to_recordset(v_lines) r(product_id uuid, qty int)
    join public.products p on p.id = r.product_id
    group by p.artisan_id
  loop
    insert into public.order_shops (order_id, artisan_id, subtotal, shipping_fee, commission)
    values (v_order_id, v_shop.artisan_id, v_shop.subtotal, v_fee, round(v_shop.subtotal * v_pct / 100, 2))
    returning id into v_order_shop_id;

    insert into public.order_items (order_shop_id, product_id, product_name, qty, unit_price)
    select v_order_shop_id, p.id, p.name, r.qty, p.price
    from jsonb_to_recordset(v_lines) r(product_id uuid, qty int)
    join public.products p on p.id = r.product_id
    where p.artisan_id = v_shop.artisan_id;

    v_total := v_total + v_shop.subtotal + v_fee;
  end loop;

  update public.products p
  set stock = p.stock - r.qty
  from jsonb_to_recordset(v_lines) r(product_id uuid, qty int)
  where p.id = r.product_id;

  update public.orders set total = v_total where id = v_order_id;
  return v_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- mock_pay_order: the demo payment page's Pay / Fail buttons.
-- A failed payment cancels the order and returns its stock.
-- ---------------------------------------------------------------------------
create or replace function public.mock_pay_order(p_order_id uuid, p_success boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop uuid;
begin
  update public.orders
  set payment_status = case when p_success then 'paid'::public.payment_status else 'failed'::public.payment_status end
  where id = p_order_id and buyer_id = auth.uid() and payment_method = 'mock' and payment_status = 'unpaid';
  if not found then
    raise exception 'This order can''t be paid';
  end if;

  if not p_success then
    for v_shop in select id from public.order_shops where order_id = p_order_id and status = 'pending' loop
      perform public.restock_order_shop(v_shop);
    end loop;
    update public.order_shops set status = 'cancelled' where order_id = p_order_id and status = 'pending';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel_order: the buyer cancels before anything ships and before paying
-- online (refunds are out of scope for version 1).
-- ---------------------------------------------------------------------------
create or replace function public.cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_shop uuid;
begin
  select * into v_order from public.orders where id = p_order_id and buyer_id = auth.uid() for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.payment_status = 'paid' then
    raise exception 'Paid orders can''t be cancelled here. Please contact the shop.';
  end if;
  if exists (select 1 from public.order_shops where order_id = p_order_id and status <> 'pending') then
    raise exception 'Part of this order has already shipped';
  end if;

  for v_shop in select id from public.order_shops where order_id = p_order_id loop
    perform public.restock_order_shop(v_shop);
  end loop;
  update public.order_shops set status = 'cancelled' where order_id = p_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- update_shop_order_status: the artisan (or owner) moves a shop order along
-- pending -> shipped -> delivered, or cancels it while still pending.
-- Cash on delivery counts as paid once every parcel has arrived.
-- ---------------------------------------------------------------------------
create or replace function public.update_shop_order_status(
  p_order_shop_id uuid,
  p_status public.shop_order_status
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  select os.id, os.order_id, os.artisan_id, os.status, o.payment_method, o.payment_status
  into v
  from public.order_shops os
  join public.orders o on o.id = os.order_id
  where os.id = p_order_shop_id
  for update of os;

  if not found then
    raise exception 'Order not found';
  end if;
  if v.artisan_id is distinct from public.my_artisan_id() and not public.is_owner() then
    raise exception 'This isn''t your order';
  end if;

  if p_status = 'shipped' then
    if v.status <> 'pending' then
      raise exception 'Only orders waiting to ship can be marked shipped';
    end if;
    if v.payment_method <> 'cod' and v.payment_status <> 'paid' then
      raise exception 'Wait for the buyer''s payment before shipping';
    end if;
    update public.order_shops set status = 'shipped', shipped_at = now() where id = p_order_shop_id;

  elsif p_status = 'delivered' then
    if v.status <> 'shipped' then
      raise exception 'Only shipped orders can be marked delivered';
    end if;
    update public.order_shops set status = 'delivered', delivered_at = now() where id = p_order_shop_id;
    if v.payment_method = 'cod' and not exists (
      select 1 from public.order_shops
      where order_id = v.order_id and status not in ('delivered', 'cancelled')
    ) then
      update public.orders set payment_status = 'paid' where id = v.order_id;
    end if;

  elsif p_status = 'cancelled' then
    if v.status <> 'pending' then
      raise exception 'Only orders that haven''t shipped can be cancelled';
    end if;
    if v.payment_status = 'paid' then
      raise exception 'Paid orders can''t be cancelled here';
    end if;
    perform public.restock_order_shop(p_order_shop_id);
    update public.order_shops set status = 'cancelled' where id = p_order_shop_id;

  else
    raise exception 'Unsupported status';
  end if;
end;
$$;

revoke execute on function public.place_order(jsonb, uuid, public.payment_method) from public, anon;
revoke execute on function public.mock_pay_order(uuid, boolean) from public, anon;
revoke execute on function public.cancel_order(uuid) from public, anon;
revoke execute on function public.update_shop_order_status(uuid, public.shop_order_status) from public, anon;
grant execute on function public.place_order(jsonb, uuid, public.payment_method) to authenticated;
grant execute on function public.mock_pay_order(uuid, boolean) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.update_shop_order_status(uuid, public.shop_order_status) to authenticated;
