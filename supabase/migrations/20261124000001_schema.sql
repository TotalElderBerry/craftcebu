-- CRAFTCEBU schema: tables, enums, indexes and triggers.
-- Row Level Security policies live in the next migration.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('buyer', 'artisan', 'owner');
create type public.artisan_status as enum ('pending', 'verified', 'rejected', 'suspended');
create type public.payment_method as enum ('maya', 'cod', 'mock');
create type public.payment_status as enum ('unpaid', 'paid', 'failed');
create type public.shop_order_status as enum ('pending', 'shipped', 'delivered', 'cancelled');
create type public.payout_status as enum ('owed', 'paid');

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role public.user_role not null default 'buyer',
  avatar_url text,
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);

-- The platform has exactly one owner account.
create unique index profiles_single_owner on public.profiles (role) where role = 'owner';

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  recipient text not null,
  phone text not null,
  street text not null,
  barangay text not null,
  city text not null,
  province text not null default 'Cebu',
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index addresses_profile_id_idx on public.addresses (profile_id);

-- ---------------------------------------------------------------------------
-- Catalog setup
-- ---------------------------------------------------------------------------
create table public.towns (
  id serial primary key,
  name text not null unique,
  lat double precision not null,
  lng double precision not null,
  known_for text not null default ''
);

create table public.categories (
  id serial primary key,
  name text not null unique,
  slug text not null unique,
  icon text
);

-- ---------------------------------------------------------------------------
-- Artisans and products
-- ---------------------------------------------------------------------------
create table public.artisans (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  shop_name text not null,
  slug text not null unique,
  story text not null default '',
  town_id int references public.towns (id),
  craft_since int check (craft_since between 1900 and 2100),
  photo_url text,
  sample_photos text[] not null default '{}',
  status public.artisan_status not null default 'pending',
  reject_reason text,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
create index artisans_status_idx on public.artisans (status);
create index artisans_town_id_idx on public.artisans (town_id);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  artisan_id uuid not null references public.artisans (id) on delete cascade,
  category_id int references public.categories (id),
  name text not null,
  slug text not null unique,
  description text not null default '',
  materials text not null default '',
  price numeric(10, 2) not null check (price >= 0),
  stock int not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  is_featured boolean not null default false,
  created_at timestamptz not null default now()
);
create index products_artisan_id_idx on public.products (artisan_id);
create index products_category_id_idx on public.products (category_id);

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  url text not null,
  sort_order int not null default 0
);
create index product_images_product_id_idx on public.product_images (product_id);

-- ---------------------------------------------------------------------------
-- Orders: one order per checkout, split into one order_shops row per artisan
-- ---------------------------------------------------------------------------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles (id),
  -- Address is copied at checkout so later edits don't change past orders.
  ship_recipient text not null,
  ship_phone text not null,
  ship_address text not null,
  total numeric(10, 2) not null check (total >= 0),
  payment_method public.payment_method not null,
  payment_status public.payment_status not null default 'unpaid',
  maya_checkout_id text,
  created_at timestamptz not null default now()
);
create index orders_buyer_id_idx on public.orders (buyer_id);

create table public.order_shops (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  artisan_id uuid not null references public.artisans (id),
  subtotal numeric(10, 2) not null check (subtotal >= 0),
  shipping_fee numeric(10, 2) not null default 0 check (shipping_fee >= 0),
  -- Stored at checkout so later commission changes don't rewrite past orders.
  commission numeric(10, 2) not null default 0 check (commission >= 0),
  status public.shop_order_status not null default 'pending',
  shipped_at timestamptz,
  delivered_at timestamptz
);
create index order_shops_order_id_idx on public.order_shops (order_id);
create index order_shops_artisan_id_idx on public.order_shops (artisan_id);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_shop_id uuid not null references public.order_shops (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  qty int not null check (qty > 0),
  unit_price numeric(10, 2) not null check (unit_price >= 0)
);
create index order_items_order_shop_id_idx on public.order_items (order_shop_id);

-- ---------------------------------------------------------------------------
-- Reviews and wishlists
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  buyer_id uuid not null references public.profiles (id) on delete cascade,
  order_item_id uuid not null unique references public.order_items (id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text not null default '',
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index reviews_product_id_idx on public.reviews (product_id);

create table public.wishlists (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, product_id)
);

-- ---------------------------------------------------------------------------
-- Owner tools
-- ---------------------------------------------------------------------------
create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  artisan_id uuid not null references public.artisans (id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  period text not null,
  status public.payout_status not null default 'owed',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index payouts_artisan_id_idx on public.payouts (artisan_id);

create table public.banners (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  link text,
  sort_order int not null default 0,
  is_active boolean not null default true
);

create table public.featured_artisans (
  id uuid primary key default gen_random_uuid(),
  artisan_id uuid not null references public.artisans (id) on delete cascade,
  week_start date not null unique
);

create table public.settings (
  key text primary key,
  value jsonb not null
);

create table public.activity_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_table text not null,
  target_id text not null,
  details jsonb,
  created_at timestamptz not null default now()
);
create index activity_log_created_at_idx on public.activity_log (created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers used by triggers and RLS
-- ---------------------------------------------------------------------------
create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'owner'
  );
$$;

-- The current user's artisan id, or null when they have no shop.
create or replace function public.my_artisan_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.artisans where profile_id = auth.uid();
$$;

-- True when a statement runs as a trusted role (SQL editor, seed, service key,
-- or a security definer function) rather than as a signed-in user.
create or replace function public.is_trusted_role()
returns boolean
language sql
stable
as $$
  select current_user in ('postgres', 'service_role', 'supabase_admin');
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Create a profile for every new auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users can edit their own profile, but never their role or ban flag.
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
as $$
begin
  if (new.role is distinct from old.role or new.is_banned is distinct from old.is_banned)
     and not public.is_trusted_role()
     and not public.is_owner() then
    raise exception 'Only the owner can change role or ban status';
  end if;
  if new.role is distinct from old.role and old.role = 'owner' and not public.is_trusted_role() then
    raise exception 'The owner role can only be changed from the database';
  end if;
  return new;
end;
$$;

create trigger guard_profile_columns
  before update on public.profiles
  for each row execute function public.guard_profile_columns();

-- Artisans can edit their shop, but only the owner decides its status.
create or replace function public.guard_artisan_columns()
returns trigger
language plpgsql
as $$
begin
  if (new.status is distinct from old.status
      or new.reject_reason is distinct from old.reject_reason
      or new.verified_at is distinct from old.verified_at
      or new.profile_id is distinct from old.profile_id)
     and not public.is_trusted_role()
     and not public.is_owner() then
    raise exception 'Only the owner can change a shop''s status';
  end if;
  return new;
end;
$$;

create trigger guard_artisan_columns
  before update on public.artisans
  for each row execute function public.guard_artisan_columns();

-- New applications always start as pending, whatever the client sends.
create or replace function public.force_pending_application()
returns trigger
language plpgsql
as $$
begin
  if not public.is_trusted_role() and not public.is_owner() then
    new.status := 'pending';
    new.reject_reason := null;
    new.verified_at := null;
  end if;
  return new;
end;
$$;

create trigger force_pending_application
  before insert on public.artisans
  for each row execute function public.force_pending_application();

-- ---------------------------------------------------------------------------
-- Owner actions on applications
-- ---------------------------------------------------------------------------
create or replace function public.review_artisan_application(
  p_artisan_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid;
begin
  if not public.is_owner() then
    raise exception 'Only the owner can review applications';
  end if;

  update public.artisans
  set status = case when p_approve then 'verified'::public.artisan_status else 'rejected'::public.artisan_status end,
      reject_reason = case when p_approve then null else p_reason end,
      verified_at = case when p_approve then now() else null end
  where id = p_artisan_id
  returning profile_id into v_profile_id;

  if v_profile_id is null then
    raise exception 'Application not found';
  end if;

  if p_approve then
    update public.profiles set role = 'artisan' where id = v_profile_id and role = 'buyer';
  end if;

  insert into public.activity_log (actor_id, action, target_table, target_id, details)
  values (
    auth.uid(),
    case when p_approve then 'approve_artisan' else 'reject_artisan' end,
    'artisans',
    p_artisan_id::text,
    case when p_approve then null else jsonb_build_object('reason', p_reason) end
  );
end;
$$;
