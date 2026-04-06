create table if not exists public.weekly_recovery_reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    procedure_id text not null,
    procedure_name text not null,
    week_number int not null check (week_number > 0),
    scheduled_date date not null,
    completed_entry_id uuid null,
    is_completed boolean not null default false,
    satisfaction_rating int null check (satisfaction_rating between 1 and 5),
    headline text null,
    observation text null,
    improvement text null,
    concern text null,
    pain_trend text null,
    swelling_status text null,
    bruising_status text null,
    redness_status text null,
    recovery_score int null,
    consistency_rate int null,
    alerts jsonb not null default '[]'::jsonb,
    metric_points jsonb not null default '[]'::jsonb,
    generated_at timestamptz null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, procedure_id, week_number)
);

create index if not exists idx_weekly_recovery_reports_user_procedure
    on public.weekly_recovery_reports(user_id, procedure_id, week_number);

alter table public.weekly_recovery_reports enable row level security;

create policy "Users can view their own weekly recovery reports"
    on public.weekly_recovery_reports for select
    using (auth.uid() = user_id);

create policy "Users can insert their own weekly recovery reports"
    on public.weekly_recovery_reports for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own weekly recovery reports"
    on public.weekly_recovery_reports for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Users can delete their own weekly recovery reports"
    on public.weekly_recovery_reports for delete
    using (auth.uid() = user_id);

drop trigger if exists weekly_recovery_reports_updated_at on public.weekly_recovery_reports;
create trigger weekly_recovery_reports_updated_at
    before update on public.weekly_recovery_reports
    for each row execute function public.set_updated_at();
