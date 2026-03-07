-- =============================================================================
-- SECURITY PATCHES
-- =============================================================================
-- PATCH 1: Restrict user_profiles UPDATE to non-sensitive columns
-- PATCH 2: Create increment_usage SECURITY DEFINER function
-- PATCH 4: Revoke get_or_create_usage_record from authenticated role
-- =============================================================================


-- -----------------------------------------------------------------------------
-- PATCH 1: Prevent users from self-modifying subscription / billing fields
-- -----------------------------------------------------------------------------
-- The old policy allowed authenticated users to UPDATE any column in their own
-- row, including subscription_tier, subscription_status, billing_plan, and
-- subscription_current_period_end — enabling free tier escalation.
-- The new policy locks those four columns to their current DB values so only
-- the service_role (Stripe webhook handler) can change them.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;

CREATE POLICY "Users can update own profile"
    ON public.user_profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id
        -- Subscription fields must stay unchanged when updated by the user
        AND billing_plan                  = (SELECT billing_plan                  FROM public.user_profiles WHERE id = auth.uid())
        AND subscription_tier             IS NOT DISTINCT FROM (SELECT subscription_tier             FROM public.user_profiles WHERE id = auth.uid())
        AND subscription_status           IS NOT DISTINCT FROM (SELECT subscription_status           FROM public.user_profiles WHERE id = auth.uid())
        AND subscription_current_period_end IS NOT DISTINCT FROM (SELECT subscription_current_period_end FROM public.user_profiles WHERE id = auth.uid())
    );


-- -----------------------------------------------------------------------------
-- PATCH 2: SECURITY DEFINER function to safely increment usage counters
-- -----------------------------------------------------------------------------
-- The Edge Functions previously issued a direct UPDATE on usage_tracking using
-- the user's JWT context (authenticated role). Because the RLS UPDATE policy
-- only allows service_role, those updates were silently failing — counters
-- were permanently stuck at 0 and every user had unlimited AI calls.
--
-- This function runs as its owner (bypasses RLS) so the increment always
-- lands, while the GRANT is limited to authenticated so it is callable from
-- Edge Functions that use the user JWT.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_usage(
    p_usage_id UUID,
    p_messages INTEGER,
    p_images   INTEGER,
    p_credits  INTEGER
)
RETURNS void AS $$
BEGIN
    UPDATE public.usage_tracking
    SET
        messages_used = messages_used + p_messages,
        images_used   = images_used   + p_images,
        credits_used  = credits_used  + p_credits
    WHERE id = p_usage_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.increment_usage TO authenticated;


-- -----------------------------------------------------------------------------
-- PATCH 4: Revoke get_or_create_usage_record from authenticated role
-- -----------------------------------------------------------------------------
-- Authenticated users could previously call this function directly with an
-- arbitrary p_tier value (e.g. 'gold') to manufacture a high-limit usage
-- record. After Patch 1 blocks tier self-escalation, this is lower risk, but
-- the function should only be callable by service_role / Edge Functions that
-- authenticate with the service key.
-- -----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.get_or_create_usage_record FROM authenticated;
-- service_role grant (set in original migration) is preserved.
