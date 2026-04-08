create or replace view public.user_acquisition_source_counts as
select
    coalesce(metadata->>'acquisition_source', 'unknown') as acquisition_source,
    coalesce(metadata->>'acquisition_source_label', 'Unknown') as acquisition_source_label,
    count(*)::bigint as user_count
from public.user_profiles
group by 1, 2
order by user_count desc, acquisition_source_label asc;

create or replace view public.user_acquisition_source_daily as
select
    date_trunc(
        'day',
        coalesce(
            nullif(metadata->>'acquisition_source_recorded_at', '')::timestamptz,
            created_at
        )
    ) as acquisition_date,
    coalesce(metadata->>'acquisition_source', 'unknown') as acquisition_source,
    coalesce(metadata->>'acquisition_source_label', 'Unknown') as acquisition_source_label,
    count(*)::bigint as user_count
from public.user_profiles
group by 1, 2, 3
order by acquisition_date desc, user_count desc, acquisition_source_label asc;

grant select on public.user_acquisition_source_counts to authenticated;
grant select on public.user_acquisition_source_daily to authenticated;
