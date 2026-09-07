-- ==============================================================================
-- ZankoAI Migration: AI OCR Processing Jobs & Results
-- Migration Version: 20260907000010_ocr_ai_processing.sql
-- ==============================================================================

-- ─── 1. ocr_jobs: tracks every OCR upload and processing request ──────────────
CREATE TABLE IF NOT EXISTS public.ocr_jobs (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    idempotency_key     TEXT        NOT NULL,
    original_filename   TEXT        NOT NULL,
    storage_path        TEXT        NOT NULL,    -- path inside 'ocr-images' bucket (never exposed as public URL)
    file_size_bytes     BIGINT      NOT NULL DEFAULT 0,
    image_width         INT         NOT NULL DEFAULT 0,
    image_height        INT         NOT NULL DEFAULT 0,
    ocr_type            TEXT        NOT NULL DEFAULT 'auto'
                            CHECK (ocr_type IN ('auto', 'printed', 'handwriting')),
    processing_type     TEXT        NOT NULL DEFAULT 'all'
                            CHECK (processing_type IN ('extract_only', 'all', 'summarize', 'quiz', 'flashcards', 'questions')),
    status              TEXT        NOT NULL DEFAULT 'queued'
                            CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    error_message       TEXT,
    bullmq_job_id       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.ocr_jobs IS
    'Tracks async OCR processing jobs: upload, handwriting/printed recognition, AI study aids generation.';

COMMENT ON COLUMN public.ocr_jobs.idempotency_key IS
    'SHA-256 hash of (userId + originalFilename + fileSizeBytes) or client provided UUID. Prevents duplicate charges.';

COMMENT ON COLUMN public.ocr_jobs.storage_path IS
    'Internal Supabase Storage path in the ocr-images bucket. Never exposed directly to clients.';

-- Unique constraint on idempotency_key per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_ocr_jobs_idempotency
    ON public.ocr_jobs (user_id, idempotency_key);

-- Fast lookup by user + recency
CREATE INDEX IF NOT EXISTS idx_ocr_jobs_user_created
    ON public.ocr_jobs (user_id, created_at DESC);

-- Status-based operational queries (cleanup, monitoring)
CREATE INDEX IF NOT EXISTS idx_ocr_jobs_status_created
    ON public.ocr_jobs (status, created_at);

-- ─── 2. ocr_job_results: stores OCR extracted text and AI-generated output ────
CREATE TABLE IF NOT EXISTS public.ocr_job_results (
    id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id                  UUID          NOT NULL REFERENCES public.ocr_jobs(id) ON DELETE CASCADE,
    user_id                 UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    extracted_text          TEXT          NOT NULL DEFAULT '',
    detected_text_type      TEXT          NOT NULL DEFAULT 'mixed'
                                CHECK (detected_text_type IN ('handwriting', 'printed', 'mixed')),
    confidence_score        NUMERIC(4, 3) DEFAULT 0.950,
    summary                 TEXT,                         -- AI-generated summary
    questions               JSONB         DEFAULT '[]'::jsonb, -- structured Q&A list
    quiz                    JSONB         DEFAULT '{}'::jsonb, -- quiz with options + answers
    flashcards              JSONB         DEFAULT '[]'::jsonb, -- [{front, back}]
    ocr_provider            TEXT          NOT NULL DEFAULT 'google',
    extracted_text_length   INT           NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.ocr_job_results IS
    'Stores recognized text and generated AI learning aids for completed OCR jobs.';

-- One result per job (1:1 relationship)
CREATE UNIQUE INDEX IF NOT EXISTS idx_ocr_job_results_job_id
    ON public.ocr_job_results (job_id);

CREATE INDEX IF NOT EXISTS idx_ocr_job_results_user_created
    ON public.ocr_job_results (user_id, created_at DESC);

-- ─── 3. updated_at auto-trigger for ocr_jobs ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_ocr_job_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ocr_jobs_updated_at ON public.ocr_jobs;
CREATE TRIGGER trg_ocr_jobs_updated_at
    BEFORE UPDATE ON public.ocr_jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.set_ocr_job_updated_at();

-- ─── 4. Row Level Security ────────────────────────────────────────────────────
ALTER TABLE public.ocr_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocr_job_results ENABLE ROW LEVEL SECURITY;

-- ocr_jobs: users view, insert, and delete only their own jobs
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users manage their own ocr jobs" ON public.ocr_jobs;
    CREATE POLICY "Users manage their own ocr jobs"
        ON public.ocr_jobs
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;

-- ocr_job_results: users view and delete only their own results
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users view their own ocr results" ON public.ocr_job_results;
    CREATE POLICY "Users view their own ocr results"
        ON public.ocr_job_results
        FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users delete their own ocr results" ON public.ocr_job_results;
    CREATE POLICY "Users delete their own ocr results"
        ON public.ocr_job_results
        FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- Service role has unrestricted access (backend worker uses service role)

-- ─── 5. RPC: get_orphaned_ocr_jobs ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_orphaned_ocr_jobs(p_older_than_hours INT DEFAULT 24)
RETURNS TABLE (
    job_id          UUID,
    user_id         UUID,
    storage_path    TEXT,
    status          TEXT,
    created_at      TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        id        AS job_id,
        user_id,
        storage_path,
        status,
        created_at
    FROM public.ocr_jobs
    WHERE status IN ('queued', 'failed')
      AND created_at < (timezone('utc', now()) - (p_older_than_hours || ' hours')::interval)
    ORDER BY created_at ASC;
$$;

COMMENT ON FUNCTION public.get_orphaned_ocr_jobs IS
    'Returns stale queued/failed OCR jobs older than the given hours threshold for retention cleanup.';

REVOKE ALL ON FUNCTION public.get_orphaned_ocr_jobs FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_orphaned_ocr_jobs TO service_role;
