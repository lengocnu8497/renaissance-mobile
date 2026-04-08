-- Add provider-agnostic subscription fields plus App Store identifiers.

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS subscription_provider TEXT CHECK (subscription_provider IN ('stripe', 'app_store')),
    ADD COLUMN IF NOT EXISTS subscription_id TEXT,
    ADD COLUMN IF NOT EXISTS app_store_product_id TEXT,
    ADD COLUMN IF NOT EXISTS app_store_original_transaction_id TEXT,
    ADD COLUMN IF NOT EXISTS app_store_environment TEXT CHECK (app_store_environment IN ('sandbox', 'production', 'xcode'));

ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS payment_provider TEXT CHECK (payment_provider IN ('stripe', 'app_store')),
    ADD COLUMN IF NOT EXISTS subscription_id TEXT,
    ADD COLUMN IF NOT EXISTS store_transaction_id TEXT,
    ADD COLUMN IF NOT EXISTS original_transaction_id TEXT;

UPDATE public.user_profiles
SET subscription_provider = 'stripe',
    subscription_id = COALESCE(subscription_id, stripe_subscription_id)
WHERE stripe_subscription_id IS NOT NULL
  AND subscription_provider IS NULL;

UPDATE public.transactions
SET payment_provider = 'stripe',
    subscription_id = COALESCE(subscription_id, stripe_subscription_id),
    store_transaction_id = COALESCE(store_transaction_id, stripe_payment_intent_id)
WHERE stripe_payment_intent_id IS NOT NULL
   OR stripe_subscription_id IS NOT NULL
   OR stripe_invoice_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_subscription_provider
    ON public.user_profiles(subscription_provider);

CREATE INDEX IF NOT EXISTS idx_user_profiles_app_store_original_transaction_id
    ON public.user_profiles(app_store_original_transaction_id);

CREATE INDEX IF NOT EXISTS idx_transactions_payment_provider
    ON public.transactions(payment_provider);

CREATE INDEX IF NOT EXISTS idx_transactions_subscription_id
    ON public.transactions(subscription_id);

CREATE INDEX IF NOT EXISTS idx_transactions_store_transaction_id
    ON public.transactions(store_transaction_id);

COMMENT ON COLUMN public.user_profiles.subscription_provider IS 'Source of truth for the current subscription record';
COMMENT ON COLUMN public.user_profiles.subscription_id IS 'Provider-agnostic subscription lineage identifier';
COMMENT ON COLUMN public.user_profiles.app_store_product_id IS 'Current App Store product identifier';
COMMENT ON COLUMN public.user_profiles.app_store_original_transaction_id IS 'Original transaction ID for the App Store subscription lineage';
COMMENT ON COLUMN public.transactions.payment_provider IS 'Payment provider that created this transaction record';
COMMENT ON COLUMN public.transactions.store_transaction_id IS 'Provider transaction identifier such as an App Store transaction ID';
