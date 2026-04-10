-- Tighten profile-image access so images are only readable by authenticated users.
-- The app now signs short-lived URLs at read time, so the bucket no longer needs
-- to be public.

update storage.buckets
set public = false
where id = 'profile-image';

drop policy if exists "Public profile images are viewable by everyone" on storage.objects;
drop policy if exists "Authenticated users can view profile images" on storage.objects;

create policy "Authenticated users can view profile images"
on storage.objects for select
to authenticated
using (bucket_id = 'profile-image');
