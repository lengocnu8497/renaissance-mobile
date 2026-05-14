-- Creates a per-user, per-day counter for the free AI chat allowance.
-- Non-subscribed users get FREE_DAILY_LIMIT questions/day (enforced in chat-ai function).

CREATE TABLE public.free_chat_usage (
    user_id    UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    usage_date DATE    NOT NULL DEFAULT CURRENT_DATE,
    count      INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE public.free_chat_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own free usage"
    ON public.free_chat_usage FOR SELECT
    USING (auth.uid() = user_id);

-- Writes are done by the service role key in the edge function (bypasses RLS).
-- No INSERT/UPDATE policy needed for anon/authenticated roles.

CREATE INDEX idx_free_chat_usage_user_date
    ON public.free_chat_usage (user_id, usage_date);
