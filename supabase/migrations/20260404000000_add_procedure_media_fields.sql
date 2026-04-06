alter table public.procedures
add column if not exists hero_image_url text,
add column if not exists thumbnail_image_url text,
add column if not exists media_source text,
add column if not exists media_license_type text,
add column if not exists media_alt_text text,
add column if not exists usage_rights_confirmed boolean default false;

comment on column public.procedures.hero_image_url is
'Primary visual used in the saved procedure detail hero. Must be owned or properly licensed.';

comment on column public.procedures.thumbnail_image_url is
'Smaller visual used for shelves, cards, and compact research list presentations.';

comment on column public.procedures.media_source is
'Where the approved procedure visual came from, for example brand-owned, licensed stock, or partner-provided.';

comment on column public.procedures.media_license_type is
'Human-readable rights classification for the asset, for example owned, licensed, or partner-consented.';

comment on column public.procedures.media_alt_text is
'Accessible description of the procedure visual for assistive technologies and editorial QA.';

comment on column public.procedures.usage_rights_confirmed is
'True only when the asset has been reviewed and confirmed safe to ship in-product.';
