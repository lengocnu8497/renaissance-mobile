-- Add Stripe subscription fields to existing user_profiles table

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT,
ADD COLUMN IF NOT EXISTS subscription_status TEXT CHECK (subscription_status IN ('active', 'canceled', 'past_due', 'trialing', 'incomplete', 'incomplete_expired', 'unpaid')),
ADD COLUMN IF NOT EXISTS subscription_tier TEXT CHECK (subscription_tier IN ('silver', 'gold')),
ADD COLUMN IF NOT EXISTS subscription_current_period_end TIMESTAMPTZ;

-- Add index for Stripe customer lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_stripe_customer_id ON public.user_profiles(stripe_customer_id);

-- Add comment
COMMENT ON COLUMN public.user_profiles.stripe_customer_id IS 'Stripe Customer ID - only payment-related data we store. All card details stored by Stripe.';
