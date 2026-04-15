-- Tighten user_profiles ownership rules so authenticated users cannot mutate
-- any subscription or App Store entitlement fields directly.

DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;

CREATE POLICY "Users can update own profile"
    ON public.user_profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id
        AND billing_plan IS NOT DISTINCT FROM (
            SELECT billing_plan
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND subscription_tier IS NOT DISTINCT FROM (
            SELECT subscription_tier
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND subscription_status IS NOT DISTINCT FROM (
            SELECT subscription_status
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND subscription_current_period_end IS NOT DISTINCT FROM (
            SELECT subscription_current_period_end
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND subscription_provider IS NOT DISTINCT FROM (
            SELECT subscription_provider
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND subscription_id IS NOT DISTINCT FROM (
            SELECT subscription_id
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND app_store_product_id IS NOT DISTINCT FROM (
            SELECT app_store_product_id
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND app_store_original_transaction_id IS NOT DISTINCT FROM (
            SELECT app_store_original_transaction_id
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
        AND app_store_environment IS NOT DISTINCT FROM (
            SELECT app_store_environment
            FROM public.user_profiles
            WHERE id = auth.uid()
        )
    );

COMMENT ON POLICY "Users can update own profile" ON public.user_profiles
IS 'Authenticated users may edit profile fields but may not change subscription or App Store entitlement state.';
