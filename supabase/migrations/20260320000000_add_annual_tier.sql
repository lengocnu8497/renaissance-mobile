-- Add 'yearly' to the subscription_tier CHECK constraint in usage_tracking
ALTER TABLE public.usage_tracking
    DROP CONSTRAINT IF EXISTS usage_tracking_subscription_tier_check;

ALTER TABLE public.usage_tracking
    ADD CONSTRAINT usage_tracking_subscription_tier_check
    CHECK (subscription_tier IN ('weekly', 'monthly', 'yearly'));

-- Update get_or_create_usage_record to handle the 'yearly' tier
-- Yearly: same message/image limits as Monthly, but 300 credits/mo
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
    -- Set tier limits
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

    -- Try to get existing record for this period
    SELECT * INTO v_usage_record
    FROM public.usage_tracking
    WHERE user_id = p_user_id
        AND period_start = p_period_start
        AND period_end = p_period_end;

    -- Create new record if doesn't exist
    IF NOT FOUND THEN
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
    END IF;

    RETURN v_usage_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
