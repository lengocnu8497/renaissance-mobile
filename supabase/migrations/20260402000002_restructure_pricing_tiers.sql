-- Reassert canonical pricing tiers: weekly/monthly/yearly.
-- Earlier migrations now create and update data using these names directly.

-- 1. Drop existing constraints first so we can re-add the canonical checks
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_subscription_tier_check;
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_billing_plan_check;

-- 2. Re-add updated constraints
ALTER TABLE user_profiles
  ADD CONSTRAINT user_profiles_subscription_tier_check
  CHECK (subscription_tier IN ('weekly', 'monthly', 'yearly'));

ALTER TABLE user_profiles
  ADD CONSTRAINT user_profiles_billing_plan_check
  CHECK (billing_plan IN ('free', 'weekly', 'monthly', 'yearly'));
