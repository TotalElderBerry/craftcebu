-- Public image buckets. Each user uploads only into a folder named after
-- their user id, e.g. product-images/<user id>/<file>.
insert into storage.buckets (id, name, public)
values
  ('product-images', 'product-images', true),
  ('artisan-photos', 'artisan-photos', true),
  ('banners', 'banners', true)
on conflict (id) do nothing;

create policy "Anyone views CRAFTCEBU images" on storage.objects
  for select using (bucket_id in ('product-images', 'artisan-photos', 'banners'));

create policy "Users upload into their own folder" on storage.objects
  for insert to authenticated with check (
    bucket_id in ('product-images', 'artisan-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users change files in their own folder" on storage.objects
  for update to authenticated using (
    bucket_id in ('product-images', 'artisan-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete files in their own folder" on storage.objects
  for delete to authenticated using (
    bucket_id in ('product-images', 'artisan-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Owner manages banner images" on storage.objects
  for all to authenticated
  using (bucket_id = 'banners' and public.is_owner())
  with check (bucket_id = 'banners' and public.is_owner());
