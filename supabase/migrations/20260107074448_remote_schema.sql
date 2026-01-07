drop extension if exists "pg_net";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


  create policy "Public profile images are viewable by everyone"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'profile-image'::text));



  create policy "Users can delete own profile image"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'profile-image'::text) AND (
CASE
    WHEN (POSITION(('/'::text) IN (name)) > 0) THEN SUBSTRING(name FROM 1 FOR (POSITION(('/'::text) IN (name)) - 1))
    ELSE name
END = (auth.uid())::text)));



  create policy "Users can update own profile image"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'profile-image'::text) AND (
CASE
    WHEN (POSITION(('/'::text) IN (name)) > 0) THEN SUBSTRING(name FROM 1 FOR (POSITION(('/'::text) IN (name)) - 1))
    ELSE name
END = (auth.uid())::text)))
with check (((bucket_id = 'profile-image'::text) AND (
CASE
    WHEN (POSITION(('/'::text) IN (name)) > 0) THEN SUBSTRING(name FROM 1 FOR (POSITION(('/'::text) IN (name)) - 1))
    ELSE name
END = (auth.uid())::text)));



  create policy "Users can upload own profile image"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'profile-image'::text) AND (
CASE
    WHEN (POSITION(('/'::text) IN (name)) > 0) THEN SUBSTRING(name FROM 1 FOR (POSITION(('/'::text) IN (name)) - 1))
    ELSE name
END = (auth.uid())::text)));



