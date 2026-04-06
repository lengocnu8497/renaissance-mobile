-- Restructure pricing tiers: silver/gold/annual → weekly/monthly/yearly
-- Silver archived on Stripe; Gold→Monthly, Annual→Yearly, new Weekly plan added.

-- 1. Drop old constraints first so data migration doesn't violate them
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_subscription_tier_check;
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_billing_plan_check;

-- 2. Migrate existing data
UPDATE user_profiles
SET subscription_tier = CASE subscription_tier
  WHEN 'gold'   THEN 'monthly'
  WHEN 'annual' THEN 'yearly'
  WHEN 'silver' THEN 'weekly'
  ELSE subscription_tier
END
WHERE subscription_tier IN ('silver', 'gold', 'annual');

UPDATE user_profiles
SET billing_plan = CASE billing_plan
  WHEN 'gold'   THEN 'monthly'
  WHEN 'annual' THEN 'yearly'
  WHEN 'silver' THEN 'weekly'
  ELSE billing_plan
END
WHERE billing_plan IN ('silver', 'gold', 'annual');

-- 3. Add updated constraints
ALTER TABLE user_profiles
  ADD CONSTRAINT user_profiles_subscription_tier_check
  CHECK (subscription_tier IN ('weekly', 'monthly', 'yearly'));

ALTER TABLE user_profiles
  ADD CONSTRAINT user_profiles_billing_plan_check
  CHECK (billing_plan IN ('free', 'weekly', 'monthly', 'yearly'));
