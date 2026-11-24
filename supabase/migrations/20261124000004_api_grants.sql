-- Table privileges for the Data API roles.
-- Newer Supabase projects don't grant these automatically on new tables, so
-- requests fail with "permission denied for table ...". Grants only open the
-- door; Row Level Security (previous migrations) still decides which rows
-- each user can see or change.

grant usage on schema public to anon, authenticated, service_role;

-- Visitors who aren't signed in only read the public catalog.
grant select on
  public.towns,
  public.categories,
  public.artisans,
  public.products,
  public.product_images,
  public.reviews,
  public.banners,
  public.featured_artisans,
  public.settings
to anon;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- The service role (server scripts such as promote-owner) bypasses RLS.
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Policies call these helpers, so every API role must be able to run them.
grant execute on all functions in schema public to anon, authenticated, service_role;
