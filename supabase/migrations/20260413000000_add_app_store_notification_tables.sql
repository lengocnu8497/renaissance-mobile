create table if not exists public.app_store_notification_events (
    id uuid primary key default gen_random_uuid(),
    notification_uuid text not null unique,
    notification_type text not null,
    subtype text null,
    notification_version text null,
    signed_payload text not null,
    signed_transaction_info text null,
    signed_renewal_info text null,
    original_transaction_id text null,
    app_account_token uuid null,
    raw_payload jsonb not null,
    processed_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists idx_app_store_notification_events_original_transaction_id
    on public.app_store_notification_events(original_transaction_id);

create index if not exists idx_app_store_notification_events_app_account_token
    on public.app_store_notification_events(app_account_token);

create table if not exists public.app_store_subscription_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid null references auth.users(id) on delete set null,
    source text not null check (source in ('client_sync', 'server_notification')),
    notification_event_id uuid null references public.app_store_notification_events(id) on delete set null,
    transaction_id text not null,
    original_transaction_id text not null,
    product_id text not null,
    subscription_tier text not null check (subscription_tier in ('weekly', 'monthly', 'yearly')),
    environment text null check (environment in ('sandbox', 'production', 'xcode')),
    expiration_date timestamptz null,
    is_active boolean not null,
    app_account_token uuid null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    unique (transaction_id, source)
);

create index if not exists idx_app_store_subscription_events_user_id
    on public.app_store_subscription_events(user_id, created_at desc);

create index if not exists idx_app_store_subscription_events_original_transaction_id
    on public.app_store_subscription_events(original_transaction_id, created_at desc);

alter table public.app_store_notification_events enable row level security;
alter table public.app_store_subscription_events enable row level security;

create policy "Users can view their own app store subscription events"
    on public.app_store_subscription_events
    for select
    to authenticated
    using (auth.uid() = user_id);

comment on table public.app_store_notification_events is 'Server-ingested App Store Server Notification payloads for audit and replay';
comment on table public.app_store_subscription_events is 'Normalized App Store entitlement events derived from verified transactions';
