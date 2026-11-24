-- Milestone 6: owner tools — payouts, user emails, and an automatic log of
-- owner actions.

-- ---------------------------------------------------------------------------
-- Emails on profiles, so the owner's Users page can show them. Profiles are
-- readable only by their owner and the platform owner (RLS), so this exposes
-- nothing new to other users.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists email text;

update public.profiles p set email = u.email from auth.users u where u.id = p.id and p.email is null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.email);
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Payouts (tracking only; no money moves).
-- Online payments (Maya, demo) reach the platform, which owes the artisan
-- subtotal + shipping - commission. With cash on delivery the artisan already
-- has the cash and owes the platform its commission. A payout settles every
-- delivered shop order not yet settled; a negative amount means the artisan
-- paid the platform.
-- ---------------------------------------------------------------------------
alter table public.payouts drop constraint if exists payouts_amount_check;
alter table public.order_shops add column if not exists payout_id uuid references public.payouts (id) on delete set null;
create index if not exists order_shops_payout_id_idx on public.order_shops (payout_id);

create or replace function public.payout_balances()
returns table (
  artisan_id uuid,
  shop_name text,
  delivered_orders int,
  online_owed numeric,
  cod_commission numeric,
  net numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    a.id,
    a.shop_name,
    count(os.id)::int,
    coalesce(sum(os.subtotal + os.shipping_fee - os.commission) filter (where o.payment_method <> 'cod'), 0),
    coalesce(sum(os.commission) filter (where o.payment_method = 'cod'), 0),
    coalesce(sum(os.subtotal + os.shipping_fee - os.commission) filter (where o.payment_method <> 'cod'), 0)
      - coalesce(sum(os.commission) filter (where o.payment_method = 'cod'), 0)
  from public.artisans a
  join public.order_shops os on os.artisan_id = a.id and os.status = 'delivered' and os.payout_id is null
  join public.orders o on o.id = os.order_id
  -- The owner sees every shop; an artisan sees only their own.
  where public.is_owner() or a.id = public.my_artisan_id()
  group by a.id, a.shop_name
  order by 6 desc;
$$;

create or replace function public.settle_payout(p_artisan_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_amount numeric;
  v_count int;
  v_first timestamptz;
  v_payout uuid;
begin
  if not public.is_owner() then
    raise exception 'Only the owner can record payouts';
  end if;

  select
    coalesce(sum(case when o.payment_method <> 'cod' then os.subtotal + os.shipping_fee - os.commission else -os.commission end), 0),
    count(*),
    min(os.delivered_at)
  into v_amount, v_count, v_first
  from public.order_shops os
  join public.orders o on o.id = os.order_id
  where os.artisan_id = p_artisan_id and os.status = 'delivered' and os.payout_id is null;

  if v_count = 0 then
    raise exception 'Nothing to settle for this shop';
  end if;

  insert into public.payouts (artisan_id, amount, period, status, paid_at)
  values (
    p_artisan_id,
    v_amount,
    to_char(coalesce(v_first, now()) at time zone 'Asia/Manila', 'Mon DD, YYYY') || ' – ' || to_char(now() at time zone 'Asia/Manila', 'Mon DD, YYYY'),
    'paid',
    now()
  )
  returning id into v_payout;

  update public.order_shops
  set payout_id = v_payout
  where artisan_id = p_artisan_id and status = 'delivered' and payout_id is null;

  insert into public.activity_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'settle_payout', 'artisans', p_artisan_id::text, jsonb_build_object('amount', v_amount, 'orders', v_count));

  return v_payout;
end;
$$;

revoke execute on function public.payout_balances() from public, anon;
revoke execute on function public.settle_payout(uuid) from public, anon;
grant execute on function public.payout_balances() to authenticated;
grant execute on function public.settle_payout(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Activity log: owner actions made with plain updates are logged by triggers,
-- so nothing depends on the browser remembering to write the log.
-- ---------------------------------------------------------------------------
create or replace function public.log_owner_action(p_action text, p_table text, p_id text, p_details jsonb default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.activity_log (actor_id, action, target_table, target_id, details)
  select auth.uid(), p_action, p_table, p_id, p_details
  where auth.uid() is not null and public.is_owner();
$$;
revoke execute on function public.log_owner_action(text, text, text, jsonb) from public, anon, authenticated;

create or replace function public.log_artisan_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Approvals and rejections are logged by review_artisan_application.
  if new.status = 'suspended' and old.status <> 'suspended' then
    perform public.log_owner_action('suspend_artisan', 'artisans', new.id::text, jsonb_build_object('shop', new.shop_name));
  elsif old.status = 'suspended' and new.status = 'verified' then
    perform public.log_owner_action('reactivate_artisan', 'artisans', new.id::text, jsonb_build_object('shop', new.shop_name));
  end if;
  return new;
end;
$$;
create trigger log_artisan_changes after update of status on public.artisans
  for each row execute function public.log_artisan_changes();

create or replace function public.log_profile_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_banned is distinct from old.is_banned then
    perform public.log_owner_action(case when new.is_banned then 'ban_user' else 'unban_user' end, 'profiles', new.id::text, jsonb_build_object('name', new.full_name));
  end if;
  return new;
end;
$$;
create trigger log_profile_changes after update of is_banned on public.profiles
  for each row execute function public.log_profile_changes();

create or replace function public.log_product_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only owner moderation is logged, not an artisan editing their own listing.
  if public.my_artisan_id() is distinct from new.artisan_id then
    if new.is_active is distinct from old.is_active then
      perform public.log_owner_action(case when new.is_active then 'unhide_product' else 'hide_product' end, 'products', new.id::text, jsonb_build_object('name', new.name));
    end if;
    if new.is_featured is distinct from old.is_featured then
      perform public.log_owner_action(case when new.is_featured then 'feature_product' else 'unfeature_product' end, 'products', new.id::text, jsonb_build_object('name', new.name));
    end if;
  end if;
  return new;
end;
$$;
create trigger log_product_changes after update of is_active, is_featured on public.products
  for each row execute function public.log_product_changes();

create or replace function public.log_review_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_hidden is distinct from old.is_hidden then
    perform public.log_owner_action(case when new.is_hidden then 'hide_review' else 'unhide_review' end, 'reviews', new.id::text, null);
  end if;
  return new;
end;
$$;
create trigger log_review_changes after update of is_hidden on public.reviews
  for each row execute function public.log_review_changes();

create or replace function public.log_setting_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.log_owner_action('update_setting', 'settings', new.key, jsonb_build_object('from', case when tg_op = 'UPDATE' then old.value end, 'to', new.value));
  return new;
end;
$$;
create trigger log_setting_changes after insert or update on public.settings
  for each row execute function public.log_setting_changes();

create or replace function public.log_featured_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.log_owner_action('feature_artisan', 'artisans', new.artisan_id::text, jsonb_build_object('week_start', new.week_start));
  return new;
end;
$$;
create trigger log_featured_changes after insert or update on public.featured_artisans
  for each row execute function public.log_featured_changes();

-- The owner reads payouts for every shop and the order rows they settle.
grant select, insert, update, delete on public.payouts to authenticated;
