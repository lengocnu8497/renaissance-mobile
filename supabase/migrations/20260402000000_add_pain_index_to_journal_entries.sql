alter table public.journal_entries
add column if not exists pain_index numeric(4,2);
