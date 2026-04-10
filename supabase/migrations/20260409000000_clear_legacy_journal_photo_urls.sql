-- Clear previously persisted long-lived signed URLs from journal entries.
-- The app now generates short-lived signed URLs on demand from photo_path.

update public.journal_entries
set photo_url = null
where photo_url is not null;
