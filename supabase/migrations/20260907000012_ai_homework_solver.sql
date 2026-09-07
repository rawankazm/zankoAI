-- ==============================================================================
-- ZankoAI Migration: AI Homework Solver
-- Migration Version: 20260907000012_ai_homework_solver.sql
-- ==============================================================================

-- ─── 1. homework_requests: tracks student & teacher homework solutions ────────
CREATE TABLE IF NOT EXISTS public.homework_requests (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject             TEXT        NOT NULL,
    course              TEXT,
    difficulty          TEXT        NOT NULL DEFAULT 'medium'
                        CHECK (difficulty IN ('easy', 'medium', 'hard', 'advanced')),
    has_image           BOOLEAN     NOT NULL DEFAULT false,
    image_mime_type     TEXT,
    text_prompt_length  INT         NOT NULL DEFAULT 0,
    language            TEXT        NOT NULL DEFAULT 'ku',
    answer              TEXT        NOT NULL,
    explanation         TEXT        NOT NULL,
    step_by_step        JSONB       NOT NULL DEFAULT '[]'::jsonb,
    mistakes_identified JSONB       NOT NULL DEFAULT '[]'::jsonb,
    hints               JSONB       NOT NULL DEFAULT '[]'::jsonb,
    related_concepts    JSONB       NOT NULL DEFAULT '[]'::jsonb,
    duration_ms         INT         NOT NULL DEFAULT 0,
    tokens_used         INT         NOT NULL DEFAULT 0,
    idempotency_key     TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.homework_requests IS
    'Stores AI homework solving requests and educational step-by-step solutions without exposing sensitive raw image data.';

-- ─── 2. Indexes for fast retrieval and idempotency lookup ─────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS idx_homework_requests_idempotency
    ON public.homework_requests (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_homework_requests_user_created
    ON public.homework_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_homework_requests_subject
    ON public.homework_requests (subject);

-- ─── 3. Row-Level Security (RLS) ──────────────────────────────────────────────
ALTER TABLE public.homework_requests ENABLE ROW LEVEL SECURITY;

-- Owner can read their own homework solutions
DROP POLICY IF EXISTS "homework_requests_owner_select" ON public.homework_requests;
CREATE POLICY "homework_requests_owner_select"
    ON public.homework_requests
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Owner can delete their own homework solutions
DROP POLICY IF EXISTS "homework_requests_owner_delete" ON public.homework_requests;
CREATE POLICY "homework_requests_owner_delete"
    ON public.homework_requests
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Service role has full access (backend API service)
DROP POLICY IF EXISTS "homework_requests_service_all" ON public.homework_requests;
CREATE POLICY "homework_requests_service_all"
    ON public.homework_requests
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
