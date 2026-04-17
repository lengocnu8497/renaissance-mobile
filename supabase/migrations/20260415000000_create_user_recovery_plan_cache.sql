CREATE TABLE IF NOT EXISTS public.user_recovery_plan_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    procedure_id TEXT,
    procedure_name TEXT NOT NULL,
    procedure_date TIMESTAMPTZ NOT NULL,
    plan_version INTEGER NOT NULL,
    input_hash TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_phase_id TEXT NOT NULL,
    current_phase_title TEXT NOT NULL,
    current_phase_status TEXT NOT NULL,
    current_phase_summary TEXT NOT NULL,
    current_phase_focus_areas JSONB NOT NULL DEFAULT '[]'::jsonb,
    personalization_summary JSONB NOT NULL DEFAULT '[]'::jsonb,
    plan_json JSONB NOT NULL,
    source TEXT NOT NULL DEFAULT 'app_generated',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_recovery_plan_cache_user_input_hash
    ON public.user_recovery_plan_cache(user_id, input_hash);

CREATE INDEX IF NOT EXISTS idx_user_recovery_plan_cache_user_generated_at
    ON public.user_recovery_plan_cache(user_id, generated_at DESC);

ALTER TABLE public.user_recovery_plan_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own recovery plan cache" ON public.user_recovery_plan_cache;
CREATE POLICY "Users can read own recovery plan cache"
    ON public.user_recovery_plan_cache
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own recovery plan cache" ON public.user_recovery_plan_cache;
CREATE POLICY "Users can insert own recovery plan cache"
    ON public.user_recovery_plan_cache
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own recovery plan cache" ON public.user_recovery_plan_cache;
CREATE POLICY "Users can update own recovery plan cache"
    ON public.user_recovery_plan_cache
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.set_user_recovery_plan_cache_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_recovery_plan_cache_updated_at ON public.user_recovery_plan_cache;
CREATE TRIGGER trg_user_recovery_plan_cache_updated_at
    BEFORE UPDATE ON public.user_recovery_plan_cache
    FOR EACH ROW
    EXECUTE FUNCTION public.set_user_recovery_plan_cache_updated_at();

COMMENT ON TABLE public.user_recovery_plan_cache
IS 'Latest cached personalized recovery plan snapshots used to ground Ask Rena responses.';

COMMENT ON COLUMN public.user_recovery_plan_cache.plan_json
IS 'Full serialized PersonalizedRecoveryPlan payload for the latest cached plan state.';
