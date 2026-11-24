-- Milestone 3: artisan onboarding.

-- A rejected applicant edits their application, then sends it back for review.
-- Status changes are owner-only (guard_artisan_columns), so this runs as a
-- security definer and only moves the caller's own rejected row to pending.
create or replace function public.resubmit_artisan_application()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.artisans
  set status = 'pending', reject_reason = null
  where profile_id = auth.uid() and status = 'rejected';

  if not found then
    raise exception 'No rejected application to resubmit';
  end if;
end;
$$;

revoke execute on function public.resubmit_artisan_application() from public, anon;
grant execute on function public.resubmit_artisan_application() to authenticated;

-- Images only, at most 5 MB each.
update storage.buckets
set file_size_limit = 5 * 1024 * 1024,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('product-images', 'artisan-photos', 'banners');
