-- Native app phase 1: one cart per signed-in shopper, shared by the website
-- and the phone app. Guests on the website keep a browser-only cart that is
-- merged in here when they sign in.

create table public.cart_items (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  qty int not null check (qty > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, product_id)
);
create index cart_items_product_id_idx on public.cart_items (product_id);

alter table public.cart_items enable row level security;

create policy "Manage own cart" on public.cart_items
  for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

grant select, insert, update, delete on public.cart_items to authenticated;
grant all on public.cart_items to service_role;

create or replace function public.touch_cart_item()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger cart_items_touch
  before update on public.cart_items
  for each row execute function public.touch_cart_item();

-- Adds pieces to the caller's cart and returns the new quantity, never more
-- than the stock on hand. Locking the product row keeps two quick taps (or two
-- devices) from both reading the old quantity.
create or replace function public.add_to_cart(p_product_id uuid, p_qty int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_stock int;
  v_qty int;
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;
  if p_qty is null or p_qty < 1 then
    raise exception 'invalid_qty';
  end if;

  select p.stock into v_stock
  from products p
  join artisans a on a.id = p.artisan_id
  where p.id = p_product_id and p.is_active and a.status = 'verified'
  for update of p;

  if not found then
    raise exception 'not_available';
  end if;
  if v_stock = 0 then
    raise exception 'sold_out';
  end if;

  insert into cart_items (profile_id, product_id, qty)
  values (v_user, p_product_id, least(p_qty, v_stock))
  on conflict (profile_id, product_id)
  do update set qty = least(cart_items.qty + p_qty, v_stock)
  returning qty into v_qty;

  return v_qty;
end;
$$;

revoke execute on function public.add_to_cart(uuid, int) from public, anon;
grant execute on function public.add_to_cart(uuid, int) to authenticated, service_role;
