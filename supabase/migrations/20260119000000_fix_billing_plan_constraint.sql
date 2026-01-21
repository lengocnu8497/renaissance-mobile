-- Fix billing_plan constraint to allow 'free', 'silver', 'gold'
-- This syncs the remote database with the intended schema

ALTER TABLE public.user_profiles
DROP CONSTRAINT IF EXISTS user_profiles_billing_plan_check;

ALTER TABLE public.user_profiles
ADD CONSTRAINT user_profiles_billing_plan_check
CHECK (billing_plan IN ('free', 'silver', 'gold'));
