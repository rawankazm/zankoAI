-- ==============================================================================
-- ZankoAI Migration: Multilingual AI Teacher TTS & Voice System
-- Migration Version: 20260911000026_create_ai_teacher_tts_system.sql
-- ==============================================================================

-- 1. Table: tts_jobs (Tracks audio synthesis requests, caching, cost, and latency)
CREATE TABLE IF NOT EXISTS public.tts_jobs (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ai_request_id       UUID        REFERENCES public.ai_requests(id) ON DELETE SET NULL,
    text_hash           VARCHAR(64) NOT NULL,
    language            VARCHAR(10) NOT NULL DEFAULT 'ku', -- 'ku' (Kurdish), 'ar' (Arabic), 'en' (English)
    voice               VARCHAR(100) NOT NULL DEFAULT 'default',
    speed               NUMERIC(3, 2) NOT NULL DEFAULT 1.00,
    status              VARCHAR(50) NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    provider            VARCHAR(50) NOT NULL DEFAULT 'google', -- 'google', 'elevenlabs', 'fallback'
    audio_url           TEXT,
    format              VARCHAR(10) NOT NULL DEFAULT 'mp3',
    duration_ms         INTEGER     NOT NULL DEFAULT 0,
    character_count     INTEGER     NOT NULL DEFAULT 0,
    estimated_cost      NUMERIC(10, 6) NOT NULL DEFAULT 0.000000, -- USD cost
    error_code          VARCHAR(100),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    failed_at           TIMESTAMPTZ
);

COMMENT ON TABLE public.tts_jobs IS
    'Tracks server-synthesized Text-to-Speech audio chunks for AI Teacher with cost and cache metadata.';

-- 2. Performance & Idempotency Indexes
CREATE INDEX IF NOT EXISTS idx_tts_jobs_user_created
    ON public.tts_jobs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tts_jobs_cache_lookup
    ON public.tts_jobs (text_hash, language, voice, speed);

CREATE INDEX IF NOT EXISTS idx_tts_jobs_status
    ON public.tts_jobs (status);

CREATE INDEX IF NOT EXISTS idx_tts_jobs_created_at
    ON public.tts_jobs (created_at DESC);

-- 3. Row Level Security (RLS)
ALTER TABLE public.tts_jobs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own tts jobs" ON public.tts_jobs;
    CREATE POLICY "Users can view their own tts jobs"
        ON public.tts_jobs
        FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Service role has full access to tts_jobs" ON public.tts_jobs;
    CREATE POLICY "Service role has full access to tts_jobs"
        ON public.tts_jobs
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;
