-- Normalize all subscription tier aliases to the canonical weekly/monthly/yearly names.
-- This forward migration is needed for already-applied databases because editing
-- historical migration files does not change a live schema.

-- Drop legacy constraints first so data can be rewritten safely.
ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_subscription_tier_check;

ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_billing_plan_check;

ALTER TABLE public.usage_tracking
    DROP CONSTRAINT IF EXISTS usage_tracking_subscription_tier_check;

-- Re-map any legacy aliases that may still exist on user_profiles.
UPDATE public.user_profiles
SET subscription_tier = CASE subscription_tier
    WHEN 'silver' THEN 'weekly'
    WHEN 'gold' THEN 'monthly'
    WHEN 'annual' THEN 'yearly'
    ELSE subscription_tier
END
WHERE subscription_tier IN ('silver', 'gold', 'annual');

UPDATE public.user_profiles
SET billing_plan = CASE billing_plan
    WHEN 'silver' THEN 'weekly'
    WHEN 'gold' THEN 'monthly'
    WHEN 'annual' THEN 'yearly'
    ELSE billing_plan
END
WHERE billing_plan IN ('silver', 'gold', 'annual');

-- Normalize usage_tracking records as well so quota RPCs and history rows use the
-- same tier vocabulary as the app and edge functions.
UPDATE public.usage_tracking
SET subscription_tier = CASE subscription_tier
    WHEN 'silver' THEN 'weekly'
    WHEN 'gold' THEN 'monthly'
    WHEN 'annual' THEN 'yearly'
    ELSE subscription_tier
END
WHERE subscription_tier IN ('silver', 'gold', 'annual');

UPDATE public.usage_tracking
SET
    messages_limit = CASE subscription_tier
        WHEN 'weekly' THEN 30
        WHEN 'monthly' THEN 75
        WHEN 'yearly' THEN 75
        ELSE messages_limit
    END,
    images_limit = CASE subscription_tier
        WHEN 'weekly' THEN 5
        WHEN 'monthly' THEN 15
        WHEN 'yearly' THEN 15
        ELSE images_limit
    END,
    credits_limit = CASE subscription_tier
        WHEN 'weekly' THEN 80
        WHEN 'monthly' THEN 210
        WHEN 'yearly' THEN 300
        ELSE credits_limit
    END
WHERE subscription_tier IN ('weekly', 'monthly', 'yearly');

-- Reassert canonical constraints.
ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_subscription_tier_check
    CHECK (subscription_tier IN ('weekly', 'monthly', 'yearly'));

ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_billing_plan_check
    CHECK (billing_plan IN ('free', 'weekly', 'monthly', 'yearly'));

ALTER TABLE public.usage_tracking
    ADD CONSTRAINT usage_tracking_subscription_tier_check
    CHECK (subscription_tier IN ('weekly', 'monthly', 'yearly'));

-- Keep the quota helper aligned with the canonical names.
CREATE OR REPLACE FUNCTION public.get_or_create_usage_record(
    p_user_id UUID,
    p_period_start TIMESTAMPTZ,
    p_period_end TIMESTAMPTZ,
    p_tier TEXT
)
RETURNS public.usage_tracking AS $$
DECLARE
    v_usage_record public.usage_tracking;
    v_messages_limit INTEGER;
    v_images_limit INTEGER;
    v_credits_limit INTEGER;
BEGIN
    IF p_tier = 'weekly' THEN
        v_messages_limit := 30;
        v_images_limit := 5;
        v_credits_limit := 80;
    ELSIF p_tier = 'monthly' THEN
        v_messages_limit := 75;
        v_images_limit := 15;
        v_credits_limit := 210;
    ELSIF p_tier = 'yearly' THEN
        v_messages_limit := 75;
        v_images_limit := 15;
        v_credits_limit := 300;
    ELSE
        RAISE EXCEPTION 'Invalid tier: %. Must be weekly, monthly, or yearly.', p_tier;
    END IF;

    SELECT * INTO v_usage_record
    FROM public.usage_tracking
    WHERE user_id = p_user_id
      AND period_start = p_period_start
      AND period_end = p_period_end;

    IF NOT FOUND THEN
        BEGIN
            INSERT INTO public.usage_tracking (
                user_id,
                period_start,
                period_end,
                messages_used,
                images_used,
                credits_used,
                messages_limit,
                images_limit,
                credits_limit,
                subscription_tier
            ) VALUES (
                p_user_id,
                p_period_start,
                p_period_end,
                0,
                0,
                0,
                v_messages_limit,
                v_images_limit,
                v_credits_limit,
                p_tier
            )
            RETURNING * INTO v_usage_record;
        EXCEPTION WHEN unique_violation THEN
            SELECT * INTO v_usage_record
            FROM public.usage_tracking
            WHERE user_id = p_user_id
              AND period_start = p_period_start
              AND period_end = p_period_end;
        END;
    END IF;

    RETURN v_usage_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_or_create_usage_record TO service_role;
