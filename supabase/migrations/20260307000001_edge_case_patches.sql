-- =============================================================================
-- EDGE CASE PATCHES
-- =============================================================================
-- EC-1: Fix get_or_create_usage_record concurrent INSERT race (unique violation → 500)
-- EC-2: Harden increment_usage with ownership check + non-negative guard
-- =============================================================================


-- -----------------------------------------------------------------------------
-- EC-1: Fix concurrent INSERT race in get_or_create_usage_record
-- -----------------------------------------------------------------------------
-- Under concurrent requests (e.g. two simultaneous first-of-period calls),
-- both transactions can pass the SELECT ... NOT FOUND check and attempt INSERT.
-- The second one hits the UNIQUE(user_id, period_start) constraint and raises an
-- exception, surfacing as a 500 to the client. Fix: wrap the INSERT in an
-- EXCEPTION handler that falls back to SELECT on unique_violation.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_or_create_usage_record(
    p_user_id      UUID,
    p_period_start TIMESTAMPTZ,
    p_period_end   TIMESTAMPTZ,
    p_tier         TEXT
)
RETURNS public.usage_tracking AS $$
DECLARE
    v_usage_record    public.usage_tracking;
    v_messages_limit  INTEGER;
    v_images_limit    INTEGER;
    v_credits_limit   INTEGER;
BEGIN
    -- Set tier limits (hardcoded — caller cannot influence these values)
    IF p_tier = 'silver' THEN
        v_messages_limit := 30;
        v_images_limit   := 5;
        v_credits_limit  := 80;
    ELSIF p_tier = 'gold' THEN
        v_messages_limit := 75;
        v_images_limit   := 15;
        v_credits_limit  := 210;
    ELSE
        RAISE EXCEPTION 'Invalid tier: %. Must be silver or gold.', p_tier;
    END IF;

    -- Try to get existing record for this period
    SELECT * INTO v_usage_record
    FROM public.usage_tracking
    WHERE user_id     = p_user_id
      AND period_start = p_period_start
      AND period_end   = p_period_end;

    IF NOT FOUND THEN
        BEGIN
            INSERT INTO public.usage_tracking (
                user_id, period_start, period_end,
                messages_used, images_used, credits_used,
                messages_limit, images_limit, credits_limit,
                subscription_tier
            ) VALUES (
                p_user_id, p_period_start, p_period_end,
                0, 0, 0,
                v_messages_limit, v_images_limit, v_credits_limit,
                p_tier
            )
            RETURNING * INTO v_usage_record;
        EXCEPTION WHEN unique_violation THEN
            -- A concurrent request inserted the record first; just fetch it
            SELECT * INTO v_usage_record
            FROM public.usage_tracking
            WHERE user_id     = p_user_id
              AND period_start = p_period_start
              AND period_end   = p_period_end;
        END;
    END IF;

    RETURN v_usage_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Restore only service_role grant (authenticated was revoked in 20260307000000)
GRANT EXECUTE ON FUNCTION public.get_or_create_usage_record TO service_role;


-- -----------------------------------------------------------------------------
-- EC-2: Harden increment_usage
-- -----------------------------------------------------------------------------
-- Two problems with the original function:
--   a) Any authenticated user could call it with an arbitrary p_usage_id,
--      touching another user's record.
--   b) Negative values for p_messages/p_images/p_credits would silently
--      decrement counters, allowing a user to reset their own quota via RPC.
-- Fix: add p_user_id ownership check in the WHERE clause and reject negatives.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_usage(
    p_usage_id UUID,
    p_user_id  UUID,
    p_messages INTEGER,
    p_images   INTEGER,
    p_credits  INTEGER
)
RETURNS void AS $$
BEGIN
    IF p_messages < 0 OR p_images < 0 OR p_credits < 0 THEN
        RAISE EXCEPTION 'increment values must be non-negative (got messages=%, images=%, credits=%)',
            p_messages, p_images, p_credits;
    END IF;

    UPDATE public.usage_tracking
    SET
        messages_used = messages_used + p_messages,
        images_used   = images_used   + p_images,
        credits_used  = credits_used  + p_credits
    WHERE id      = p_usage_id
      AND user_id = p_user_id;   -- ownership guard: silently no-ops if IDs don't match
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.increment_usage TO authenticated;
