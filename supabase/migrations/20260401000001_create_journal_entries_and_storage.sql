-- Bootstrap journal entry schema before follow-up migrations extend it.
-- This migration is written to be idempotent so it can be marked as applied
-- on environments where the table or bucket was created manually.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create table if not exists public.journal_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    procedure_id text not null,
    procedure_name text not null,
    day_number int not null,
    entry_date date not null default current_date,
    notes text,
    photo_path text,
    photo_url text,
    analysis_json jsonb,
    swelling_index numeric(4,2),
    bruising_index numeric(4,2),
    redness_index numeric(4,2),
    overall_score numeric(4,2),
    summary text,
    zones jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_journal_entries_user_id
    on public.journal_entries(user_id);

create index if not exists idx_journal_entries_user_procedure
    on public.journal_entries(user_id, procedure_id, entry_date);

alter table public.journal_entries enable row level security;

drop trigger if exists journal_entries_updated_at on public.journal_entries;
create trigger journal_entries_updated_at
    before update on public.journal_entries
    for each row execute function public.set_updated_at();

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'journal_entries'
          and policyname = 'Users can view their own journal entries'
    ) then
        create policy "Users can view their own journal entries"
            on public.journal_entries for select
            using (auth.uid() = user_id);
    end if;
end
$$;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'journal_entries'
          and policyname = 'Users can insert their own journal entries'
    ) then
        create policy "Users can insert their own journal entries"
            on public.journal_entries for insert
            with check (auth.uid() = user_id);
    end if;
end
$$;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'journal_entries'
          and policyname = 'Users can update their own journal entries'
    ) then
        create policy "Users can update their own journal entries"
            on public.journal_entries for update
            using (auth.uid() = user_id)
            with check (auth.uid() = user_id);
    end if;
end
$$;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'journal_entries'
          and policyname = 'Users can delete their own journal entries'
    ) then
        create policy "Users can delete their own journal entries"
            on public.journal_entries for delete
            using (auth.uid() = user_id);
    end if;
end
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'journals',
    'journals',
    false,
    10485760,
    array['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
set
    name = excluded.name,
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and policyname = 'Users upload own journal photos'
    ) then
        create policy "Users upload own journal photos"
            on storage.objects for insert
            with check (
                bucket_id = 'journals'
                and auth.uid()::text = (storage.foldername(name))[1]
            );
    end if;
end
$$;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and policyname = 'Users read own journal photos'
    ) then
        create policy "Users read own journal photos"
            on storage.objects for select
            using (
                bucket_id = 'journals'
                and auth.uid()::text = (storage.foldername(name))[1]
            );
    end if;
end
$$;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and policyname = 'Users delete own journal photos'
    ) then
        create policy "Users delete own journal photos"
            on storage.objects for delete
            using (
                bucket_id = 'journals'
                and auth.uid()::text = (storage.foldername(name))[1]
            );
    end if;
end
$$;
