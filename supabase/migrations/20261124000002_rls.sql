-- CRAFTCEBU Row Level Security.
-- Buyers see their own data, artisans their own shop, the owner everything.
-- The public catalog only shows verified shops and active products.

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.towns enable row level security;
alter table public.categories enable row level security;
alter table public.artisans enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.orders enable row level security;
alter table public.order_shops enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;
alter table public.wishlists enable row level security;
alter table public.payouts enable row level security;
alter table public.banners enable row level security;
alter table public.featured_artisans enable row level security;
alter table public.settings enable row level security;
alter table public.activity_log enable row level security;

-- Helpers that read across orders and order_shops without tripping each
-- other's policies (which would recurse).
create or replace function public.is_order_buyer(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.orders where id = p_order_id and buyer_id = auth.uid());
$$;

create or replace function public.order_has_my_shop(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.order_shops
    where order_id = p_order_id and artisan_id = public.my_artisan_id()
  );
$$;

create or replace function public.is_verified_artisan(p_artisan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.artisans where id = p_artisan_id and status = 'verified');
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy "Read own profile or owner reads all" on public.profiles
  for select using (id = auth.uid() or public.is_owner());

create policy "Update own profile or owner updates any" on public.profiles
  for update using (id = auth.uid() or public.is_owner());

-- ---------------------------------------------------------------------------
-- addresses
-- ---------------------------------------------------------------------------
create policy "Manage own addresses" on public.addresses
  for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy "Owner reads addresses" on public.addresses
  for select using (public.is_owner());

-- ---------------------------------------------------------------------------
-- towns, categories, banners, featured artisans, settings: public read, owner write
-- ---------------------------------------------------------------------------
create policy "Anyone reads towns" on public.towns for select using (true);
create policy "Owner manages towns" on public.towns
  for all using (public.is_owner()) with check (public.is_owner());

create policy "Anyone reads categories" on public.categories for select using (true);
create policy "Owner manages categories" on public.categories
  for all using (public.is_owner()) with check (public.is_owner());

create policy "Anyone reads active banners" on public.banners
  for select using (is_active or public.is_owner());
create policy "Owner manages banners" on public.banners
  for all using (public.is_owner()) with check (public.is_owner());

create policy "Anyone reads featured artisans" on public.featured_artisans for select using (true);
create policy "Owner manages featured artisans" on public.featured_artisans
  for all using (public.is_owner()) with check (public.is_owner());

create policy "Anyone reads settings" on public.settings for select using (true);
create policy "Owner manages settings" on public.settings
  for all using (public.is_owner()) with check (public.is_owner());

-- ---------------------------------------------------------------------------
-- artisans
-- ---------------------------------------------------------------------------
create policy "Anyone reads verified shops; applicants read their own" on public.artisans
  for select using (status = 'verified' or profile_id = auth.uid() or public.is_owner());

create policy "Signed-in users apply for their own shop" on public.artisans
  for insert to authenticated with check (profile_id = auth.uid());

create policy "Artisans edit their own shop; owner edits any" on public.artisans
  for update using (profile_id = auth.uid() or public.is_owner());

create policy "Owner deletes shops" on public.artisans
  for delete using (public.is_owner());

-- ---------------------------------------------------------------------------
-- products and images
-- ---------------------------------------------------------------------------
create policy "Anyone reads active products of verified shops" on public.products
  for select using (
    (is_active and public.is_verified_artisan(artisan_id))
    or artisan_id = public.my_artisan_id()
    or public.is_owner()
  );

create policy "Verified artisans add their own products" on public.products
  for insert to authenticated with check (
    artisan_id = public.my_artisan_id() and public.is_verified_artisan(artisan_id)
  );

create policy "Artisans edit their own products; owner moderates" on public.products
  for update using (artisan_id = public.my_artisan_id() or public.is_owner());

create policy "Artisans delete their own products; owner too" on public.products
  for delete using (artisan_id = public.my_artisan_id() or public.is_owner());

-- Visible when its product is visible (the products policy applies here).
create policy "Read images of visible products" on public.product_images
  for select using (exists (select 1 from public.products p where p.id = product_id));

create policy "Artisans manage their own product images" on public.product_images
  for all using (
    exists (select 1 from public.products p where p.id = product_id and p.artisan_id = public.my_artisan_id())
    or public.is_owner()
  ) with check (
    exists (select 1 from public.products p where p.id = product_id and p.artisan_id = public.my_artisan_id())
    or public.is_owner()
  );

-- ---------------------------------------------------------------------------
-- orders. Inserts happen only through the place_order function (Milestone 4).
-- ---------------------------------------------------------------------------
create policy "Buyer, involved artisans and owner read orders" on public.orders
  for select using (
    buyer_id = auth.uid() or public.order_has_my_shop(id) or public.is_owner()
  );

create policy "Owner updates orders" on public.orders
  for update using (public.is_owner());

create policy "Buyer, its artisan and owner read shop orders" on public.order_shops
  for select using (
    public.is_order_buyer(order_id) or artisan_id = public.my_artisan_id() or public.is_owner()
  );

create policy "Artisan updates its own shop orders; owner any" on public.order_shops
  for update using (artisan_id = public.my_artisan_id() or public.is_owner());

create policy "Read items of visible shop orders" on public.order_items
  for select using (exists (select 1 from public.order_shops os where os.id = order_shop_id));

-- ---------------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------------
create policy "Anyone reads visible reviews" on public.reviews
  for select using (not is_hidden or buyer_id = auth.uid() or public.is_owner());

create policy "Buyers review items they received" on public.reviews
  for insert to authenticated with check (
    buyer_id = auth.uid()
    and exists (
      select 1
      from public.order_items oi
      join public.order_shops os on os.id = oi.order_shop_id
      join public.orders o on o.id = os.order_id
      where oi.id = order_item_id
        and oi.product_id = reviews.product_id
        and o.buyer_id = auth.uid()
        and os.status = 'delivered'
    )
  );

create policy "Buyers edit their own reviews; owner moderates" on public.reviews
  for update using (buyer_id = auth.uid() or public.is_owner());

create policy "Buyers delete their own reviews; owner too" on public.reviews
  for delete using (buyer_id = auth.uid() or public.is_owner());

-- ---------------------------------------------------------------------------
-- wishlists
-- ---------------------------------------------------------------------------
create policy "Manage own wishlist" on public.wishlists
  for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- payouts and activity log
-- ---------------------------------------------------------------------------
create policy "Artisans read their own payouts; owner all" on public.payouts
  for select using (artisan_id = public.my_artisan_id() or public.is_owner());

create policy "Owner manages payouts" on public.payouts
  for all using (public.is_owner()) with check (public.is_owner());

create policy "Owner reads activity log" on public.activity_log
  for select using (public.is_owner());

create policy "Owner writes activity log" on public.activity_log
  for insert with check (public.is_owner() and actor_id = auth.uid());
