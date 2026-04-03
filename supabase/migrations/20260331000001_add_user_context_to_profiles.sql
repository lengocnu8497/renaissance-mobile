-- Add user context fields to user_profiles for AI personalization
-- These fields are collected during onboarding and surfaced in EditProfileView.
-- The AI concierge uses them to build a personalized system context (RAG-style).

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS gender                TEXT,
  ADD COLUMN IF NOT EXISTS age_range             TEXT,
  ADD COLUMN IF NOT EXISTS race_ethnicity        TEXT,
  ADD COLUMN IF NOT EXISTS aesthetic_goals       TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS procedures_of_interest TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS previous_procedures   TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS health_flags          TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS body_areas_of_interest TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.user_profiles.gender IS 'Self-reported gender identity from onboarding';
COMMENT ON COLUMN public.user_profiles.age_range IS 'Age bracket, e.g. "25-34"';
COMMENT ON COLUMN public.user_profiles.race_ethnicity IS 'Self-reported race/ethnicity (optional)';
COMMENT ON COLUMN public.user_profiles.aesthetic_goals IS 'What outcomes the user is seeking';
COMMENT ON COLUMN public.user_profiles.procedures_of_interest IS 'Procedures the user wants to learn about (pre-consultation)';
COMMENT ON COLUMN public.user_profiles.previous_procedures IS 'Procedures the user has already had (post-op context)';
COMMENT ON COLUMN public.user_profiles.health_flags IS 'General health considerations, no diagnosis';
COMMENT ON COLUMN public.user_profiles.body_areas_of_interest IS 'Body areas the user is focused on';
