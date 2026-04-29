-- Migration: Create push_tokens table for APNs device token storage
-- Each user can have multiple tokens (multiple devices)

CREATE TABLE IF NOT EXISTS public.push_tokens (
    id          uuid        NOT NULL DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL,
    token       text        NOT NULL,
    platform    text        NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT push_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
    -- One token can only belong to one user at a time (device re-registration)
    CONSTRAINT push_tokens_token_unique UNIQUE (token)
);

-- Index for fast lookup by user
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON public.push_tokens(user_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_push_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_push_tokens_updated_at
    BEFORE UPDATE ON public.push_tokens
    FOR EACH ROW EXECUTE FUNCTION update_push_tokens_updated_at();

-- RLS: users can only manage their own tokens
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own push tokens"
    ON public.push_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own push tokens"
    ON public.push_tokens FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own push tokens"
    ON public.push_tokens FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read their own push tokens"
    ON public.push_tokens FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can read all tokens (needed by Edge Function)
CREATE POLICY "Service role can read all push tokens"
    ON public.push_tokens FOR SELECT
    USING (auth.role() = 'service_role');
