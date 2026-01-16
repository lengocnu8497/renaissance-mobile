-- Create usage_tracking table for monthly quota management
CREATE TABLE public.usage_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Billing period boundaries
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,

    -- Usage counters
    messages_used INTEGER NOT NULL DEFAULT 0,
    images_used INTEGER NOT NULL DEFAULT 0,
    credits_used INTEGER NOT NULL DEFAULT 0,

    -- Tier limits (denormalized for fast checking)
    messages_limit INTEGER NOT NULL,
    images_limit INTEGER NOT NULL,
    credits_limit INTEGER NOT NULL,

    -- Subscription reference
    subscription_tier TEXT CHECK (subscription_tier IN ('silver', 'gold')),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure one record per user per period
    UNIQUE(user_id, period_start)
);

-- Create indexes for efficient queries
CREATE INDEX idx_usage_tracking_user_id ON public.usage_tracking(user_id);
CREATE INDEX idx_usage_tracking_period_end ON public.usage_tracking(period_end);
CREATE INDEX idx_usage_tracking_user_period ON public.usage_tracking(user_id, period_start, period_end);

-- Enable Row Level Security
ALTER TABLE public.usage_tracking ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own usage
CREATE POLICY "Users can view own usage"
    ON public.usage_tracking
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- RLS Policy: Only service role (Edge Functions) can insert
CREATE POLICY "Service role can insert usage"
    ON public.usage_tracking
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- RLS Policy: Only service role (Edge Functions) can update
CREATE POLICY "Service role can update usage"
    ON public.usage_tracking
    FOR UPDATE
    TO service_role
    USING (true);

-- Trigger: Automatically update updated_at timestamp
CREATE TRIGGER update_usage_tracking_updated_at
    BEFORE UPDATE ON public.usage_tracking
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Helper function: Get or create usage record for current billing period
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
    IF p_tier = 'silver' THEN
        v_messages_limit := 30;
        v_images_limit := 5;
        v_credits_limit := 80;
    ELSIF p_tier = 'gold' THEN
        v_messages_limit := 75;
        v_images_limit := 15;
        v_credits_limit := 210;
    ELSE
        RAISE EXCEPTION 'Invalid tier: %. Must be silver or gold.', p_tier;
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_or_create_usage_record TO service_role;
GRANT EXECUTE ON FUNCTION public.get_or_create_usage_record TO authenticated;

-- Initialize usage records for existing active subscribers
-- This creates records for current billing period with zero usage
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
)
SELECT
    id as user_id,
    (subscription_current_period_end - INTERVAL '1 month') as period_start,
    subscription_current_period_end as period_end,
    0 as messages_used,
    0 as images_used,
    0 as credits_used,
    CASE
        WHEN subscription_tier = 'silver' THEN 30
        WHEN subscription_tier = 'gold' THEN 75
    END as messages_limit,
    CASE
        WHEN subscription_tier = 'silver' THEN 5
        WHEN subscription_tier = 'gold' THEN 15
    END as images_limit,
    CASE
        WHEN subscription_tier = 'silver' THEN 80
        WHEN subscription_tier = 'gold' THEN 210
    END as credits_limit,
    subscription_tier
FROM public.user_profiles
WHERE subscription_status = 'active'
    AND subscription_tier IN ('silver', 'gold')
    AND subscription_current_period_end IS NOT NULL
ON CONFLICT (user_id, period_start) DO NOTHING;

-- Grant table permissions
GRANT SELECT ON public.usage_tracking TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.usage_tracking TO service_role;
