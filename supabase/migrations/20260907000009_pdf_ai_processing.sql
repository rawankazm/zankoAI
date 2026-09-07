-- ==============================================================================
-- ZankoAI Migration: PDF AI Processing Jobs & Results
-- Migration Version: 20260907000009_pdf_ai_processing.sql
-- ==============================================================================

-- ─── 1. pdf_jobs: tracks every PDF upload/processing request ──────────────────
CREATE TABLE IF NOT EXISTS public.pdf_jobs (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    idempotency_key     TEXT        NOT NULL,
    original_filename   TEXT        NOT NULL,
    storage_path        TEXT        NOT NULL,    -- path inside 'pdfs' bucket (never exposed as URL)
    file_size_bytes     BIGINT      NOT NULL DEFAULT 0,
    page_count          INT         NOT NULL DEFAULT 0,
    processing_type     TEXT        NOT NULL DEFAULT 'all'
                            CHECK (processing_type IN ('all', 'summarize', 'quiz', 'flashcards', 'questions')),
    status              TEXT        NOT NULL DEFAULT 'queued'
                            CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    error_message       TEXT,
    bullmq_job_id       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.pdf_jobs IS
    'Tracks async PDF processing jobs: upload, extraction, AI generation. Status: queued→processing→completed|failed.';

COMMENT ON COLUMN public.pdf_jobs.idempotency_key IS
    'SHA-256 hash of (userId + originalFilename + fileSizeBytes). Prevents duplicate processing on retries.';

COMMENT ON COLUMN public.pdf_jobs.storage_path IS
    'Internal Supabase Storage path in the pdfs bucket. Never exposed directly to clients.';

-- Unique constraint on idempotency_key per user (cross-user key collision is acceptable)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pdf_jobs_idempotency
    ON public.pdf_jobs (user_id, idempotency_key);

-- Fast lookup by user + recency
CREATE INDEX IF NOT EXISTS idx_pdf_jobs_user_created
    ON public.pdf_jobs (user_id, created_at DESC);

-- Status-based operational queries (cleanup, monitoring)
CREATE INDEX IF NOT EXISTS idx_pdf_jobs_status_created
    ON public.pdf_jobs (status, created_at);

-- ─── 2. pdf_job_results: stores AI-generated output ──────────────────────────
CREATE TABLE IF NOT EXISTS public.pdf_job_results (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id                  UUID        NOT NULL REFERENCES public.pdf_jobs(id) ON DELETE CASCADE,
    user_id                 UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary                 TEXT,                       -- AI-generated summary
    questions               JSONB       DEFAULT '[]'::jsonb, -- structured Q&A list
    quiz                    JSONB       DEFAULT '{}'::jsonb, -- quiz with options + answers
    flashcards              JSONB       DEFAULT '[]'::jsonb, -- [{front, back}]
    extracted_text_length   INT         NOT NULL DEFAULT 0,  -- char count (not the raw text)
    created_at              TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.pdf_job_results IS
    'Stores AI output for completed PDF jobs. Raw extracted text is NOT persisted for privacy.';

-- One result per job (1:1 relationship)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pdf_job_results_job_id
    ON public.pdf_job_results (job_id);

CREATE INDEX IF NOT EXISTS idx_pdf_job_results_user_created
    ON public.pdf_job_results (user_id, created_at DESC);

-- ─── 3. updated_at auto-trigger for pdf_jobs ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_pdf_job_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pdf_jobs_updated_at ON public.pdf_jobs;
CREATE TRIGGER trg_pdf_jobs_updated_at
    BEFORE UPDATE ON public.pdf_jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.set_pdf_job_updated_at();

-- ─── 4. Row Level Security ────────────────────────────────────────────────────
ALTER TABLE public.pdf_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pdf_job_results ENABLE ROW LEVEL SECURITY;

-- pdf_jobs: users see and manage only their own jobs
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users manage their own pdf jobs" ON public.pdf_jobs;
    CREATE POLICY "Users manage their own pdf jobs"
        ON public.pdf_jobs
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;

-- pdf_job_results: users see only their own results
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users view their own pdf results" ON public.pdf_job_results;
    CREATE POLICY "Users view their own pdf results"
        ON public.pdf_job_results
        FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- Service role has unrestricted access (backend worker uses service role)
-- (No additional policy needed — service_role bypasses RLS by default)

-- ─── 5. RPC: get_orphaned_pdf_jobs ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_orphaned_pdf_jobs(p_older_than_hours INT DEFAULT 24)
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
    FROM public.pdf_jobs
    WHERE status IN ('queued', 'failed')
      AND created_at < (timezone('utc', now()) - (p_older_than_hours || ' hours')::interval)
    ORDER BY created_at ASC;
$$;

COMMENT ON FUNCTION public.get_orphaned_pdf_jobs IS
    'Returns stale queued/failed PDF jobs older than the given hours threshold for cleanup.';

REVOKE ALL ON FUNCTION public.get_orphaned_pdf_jobs FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_orphaned_pdf_jobs TO service_role;
