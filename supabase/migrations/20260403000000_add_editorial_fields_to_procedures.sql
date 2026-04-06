alter table public.procedures
add column if not exists editorial_summary text,
add column if not exists default_consult_questions jsonb;

comment on column public.procedures.editorial_summary is
'Short editorial summary used in the procedure detail hero.';

comment on column public.procedures.default_consult_questions is
'Suggested consultation questions shown before a user saves their own questions.';
