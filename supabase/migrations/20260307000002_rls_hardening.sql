-- =============================================================================
-- RLS HARDENING
-- =============================================================================
-- H-1: Revoke anon grants on tables that require authentication
-- H-2: Fix chat_messages INSERT — add conversation ownership check
-- H-3: Change all chat + transaction policies from `to public` to `to authenticated`
-- H-4: Revoke INSERT/UPDATE/DELETE from authenticated on transactions
--       (all payment writes go through service_role Edge Functions)
-- H-5: Add explicit DENY DELETE + INSERT + UPDATE on usage_tracking for authenticated
--       (no-policy = deny by default under RLS, but explicit is unambiguous)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- H-1: Revoke anon grants
-- -----------------------------------------------------------------------------
-- The original migrations issued GRANT ALL to anon on these tables.
-- RLS policies block anon access already, but grants should follow least-privilege.
-- Revoking here prevents any future policy misconfiguration from accidentally
-- opening access to unauthenticated callers.
-- -----------------------------------------------------------------------------

REVOKE ALL ON public.chat_conversations FROM anon;
REVOKE ALL ON public.chat_messages      FROM anon;
REVOKE ALL ON public.transactions       FROM anon;

-- Restore the minimum authenticated grants for transactions (SELECT only —
-- authenticated users may view their own, but all writes go through service_role)
REVOKE INSERT, UPDATE, DELETE ON public.transactions FROM authenticated;


-- -----------------------------------------------------------------------------
-- H-2: Fix chat_messages INSERT — add conversation ownership check
-- -----------------------------------------------------------------------------
-- The original policy only checked `auth.uid() = user_id` on the NEW message.
-- It did NOT verify that the target conversation belongs to the same user.
-- This allowed User A to insert messages into User B's conversation by knowing
-- the conversation UUID (user_id on the message would be User A's, so they
-- would pass the old check). The injected message is invisible to User B (their
-- SELECT policy filters by user_id), but the data exists in the DB and would
-- cause confusion if User B later queries conversation metadata (message counts,
-- updated_at triggers, etc.).
-- Fix: add an EXISTS sub-check verifying conversation ownership.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can create own messages" ON public.chat_messages;
CREATE POLICY "Users can create own messages"
    ON public.chat_messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.chat_conversations
            WHERE id = conversation_id AND user_id = auth.uid()
        )
    );


-- -----------------------------------------------------------------------------
-- H-3: Replace `to public` policies with `to authenticated` on chat tables
-- -----------------------------------------------------------------------------
-- `to public` includes both `authenticated` and `anon`. No unauthenticated user
-- should ever read, write, update, or delete chat data.
-- -----------------------------------------------------------------------------

-- chat_conversations
DROP POLICY IF EXISTS "Users can create own conversations"  ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can delete own conversations"  ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can update own conversations"  ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can view own conversations"    ON public.chat_conversations;

CREATE POLICY "Users can create own conversations"
    ON public.chat_conversations FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations"
    ON public.chat_conversations FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations"
    ON public.chat_conversations FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own conversations"
    ON public.chat_conversations FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- chat_messages
DROP POLICY IF EXISTS "Users can delete own messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can update own messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can view own messages"   ON public.chat_messages;

CREATE POLICY "Users can delete own messages"
    ON public.chat_messages FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own messages"
    ON public.chat_messages FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own messages"
    ON public.chat_messages FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- transactions
DROP POLICY IF EXISTS "Only Edge Functions can delete transactions" ON public.transactions;
DROP POLICY IF EXISTS "Only Edge Functions can insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "Only Edge Functions can update transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view own transactions"            ON public.transactions;

-- Authenticated users: read their own transactions only; all writes via service_role
CREATE POLICY "Users can view own transactions"
    ON public.transactions FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Explicit deny for direct writes (service_role bypasses RLS and handles all writes)
CREATE POLICY "Block direct transaction inserts"
    ON public.transactions FOR INSERT TO authenticated
    WITH CHECK (false);

CREATE POLICY "Block direct transaction updates"
    ON public.transactions FOR UPDATE TO authenticated
    USING (false);

CREATE POLICY "Block direct transaction deletes"
    ON public.transactions FOR DELETE TO authenticated
    USING (false);


-- -----------------------------------------------------------------------------
-- H-5: Explicit DENY on usage_tracking for authenticated writes and deletes
-- -----------------------------------------------------------------------------
-- All usage_tracking writes are done by SECURITY DEFINER functions (increment_usage,
-- get_or_create_usage_record). Authenticated users should never be able to directly
-- insert, update, or delete usage records — even accidentally.
-- Without explicit policies the default under RLS is deny, but explicit DENY
-- makes the intent unambiguous and survives future grant changes.
-- -----------------------------------------------------------------------------

CREATE POLICY "Block direct usage inserts"
    ON public.usage_tracking FOR INSERT TO authenticated
    WITH CHECK (false);

CREATE POLICY "Block direct usage updates"
    ON public.usage_tracking FOR UPDATE TO authenticated
    USING (false);

CREATE POLICY "Block direct usage deletes"
    ON public.usage_tracking FOR DELETE TO authenticated
    USING (false);