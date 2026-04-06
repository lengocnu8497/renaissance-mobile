-- Force PostgREST to reload its schema cache so the new user_profiles
-- columns (aesthetic_goals, health_flags, etc.) are immediately visible.
NOTIFY pgrst, 'reload schema';
