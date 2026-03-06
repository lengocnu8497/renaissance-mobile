-- ============================================================
-- Renaissance Mobile: Photo Journal
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Create the journal_entries table
CREATE TABLE IF NOT EXISTS public.journal_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    procedure_id    TEXT NOT NULL,          -- matches ProcedurePricing.id / ReadinessData id
    procedure_name  TEXT NOT NULL,
    day_number      INT NOT NULL,           -- day 0 = day of procedure, 1 = day after, etc.
    entry_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    notes           TEXT,
    photo_path      TEXT,                   -- Supabase Storage path: journals/{user_id}/{id}.jpg
    photo_url       TEXT,                   -- public/signed URL cached at write time

    -- Gemini Vision analysis results (nullable — analysis is optional)
    analysis_json   JSONB,                  -- full structured response from Gemini
    swelling_index  NUMERIC(4,2),           -- 0.0–10.0
    bruising_index  NUMERIC(4,2),
    redness_index   NUMERIC(4,2),
    overall_score   NUMERIC(4,2),           -- composite recovery score 0–10
    summary         TEXT,                   -- 1-2 sentence natural language summary
    zones           JSONB,                  -- per-zone breakdown [{zone, score, notes}]

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS journal_entries_updated_at ON public.journal_entries;
CREATE TRIGGER journal_entries_updated_at
    BEFORE UPDATE ON public.journal_entries
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id
    ON public.journal_entries(user_id);

CREATE INDEX IF NOT EXISTS idx_journal_entries_user_procedure
    ON public.journal_entries(user_id, procedure_id, entry_date);

-- 4. Enable Row Level Security
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies — users can only touch their own rows
CREATE POLICY "Users can view their own journal entries"
    ON public.journal_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own journal entries"
    ON public.journal_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own journal entries"
    ON public.journal_entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own journal entries"
    ON public.journal_entries FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 6. Supabase Storage bucket: "journals"
-- Run separately or via Dashboard > Storage > New Bucket
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('journals', 'journals', false)
-- ON CONFLICT DO NOTHING;

-- Storage RLS: users access only their own folder journals/{user_id}/
-- CREATE POLICY "Users upload own journal photos"
--     ON storage.objects FOR INSERT
--     WITH CHECK (bucket_id = 'journals' AND auth.uid()::text = (storage.foldername(name))[1]);

-- CREATE POLICY "Users read own journal photos"
--     ON storage.objects FOR SELECT
--     USING (bucket_id = 'journals' AND auth.uid()::text = (storage.foldername(name))[1]);

-- CREATE POLICY "Users delete own journal photos"
--     ON storage.objects FOR DELETE
--     USING (bucket_id = 'journals' AND auth.uid()::text = (storage.foldername(name))[1]);
