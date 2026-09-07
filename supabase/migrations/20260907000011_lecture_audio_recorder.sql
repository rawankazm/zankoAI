-- ==============================================================================
-- ZankoAI Migration: Teacher Lecture Audio Recorder & Processing
-- Migration Version: 20260907000011_lecture_audio_recorder.sql
-- ==============================================================================

-- ─── 1. lecture_audio_jobs: tracks teacher lecture recording requests ─────────
CREATE TABLE IF NOT EXISTS public.lecture_audio_jobs (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    course_id           UUID        NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    lecture_id          UUID        REFERENCES public.lectures(id) ON DELETE SET NULL,
    title               TEXT        NOT NULL,
    storage_path        TEXT        NOT NULL,    -- path inside 'audio' bucket (never exposed directly)
    file_size_bytes     BIGINT      NOT NULL DEFAULT 0,
    duration_seconds    INT         NOT NULL DEFAULT 0,
    audio_format        TEXT        NOT NULL DEFAULT 'audio/mp4',
    idempotency_key     TEXT        NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'queued'
                            CHECK (status IN (
                                'queued',
                                'processing',
                                'transcribing',
                                'summarizing',
                                'generating',
                                'completed',
                                'failed'
                            )),
    is_published        BOOLEAN     NOT NULL DEFAULT true,
    error_message       TEXT,
    bullmq_job_id       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.lecture_audio_jobs IS
    'Tracks teacher lecture audio recordings and async AI processing pipeline through 7 states.';

-- Prevent duplicate uploads on network retry
CREATE UNIQUE INDEX IF NOT EXISTS idx_lecture_audio_jobs_idempotency
    ON public.lecture_audio_jobs (teacher_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_lecture_audio_jobs_course_created
    ON public.lecture_audio_jobs (course_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lecture_audio_jobs_teacher_created
    ON public.lecture_audio_jobs (teacher_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lecture_audio_jobs_status_created
    ON public.lecture_audio_jobs (status, created_at);

-- ─── 2. lecture_audio_results: transcript, summary, flashcards, and quiz ──────
CREATE TABLE IF NOT EXISTS public.lecture_audio_results (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id              UUID        NOT NULL REFERENCES public.lecture_audio_jobs(id) ON DELETE CASCADE,
    course_id           UUID        NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    transcript          TEXT        NOT NULL DEFAULT '',
    summary             TEXT,
    key_takeaways       JSONB       DEFAULT '[]'::jsonb,
    flashcards          JSONB       DEFAULT '[]'::jsonb,
    quiz                JSONB       DEFAULT '{}'::jsonb,
    language_detected   TEXT        DEFAULT 'ku',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.lecture_audio_results IS
    'Stores full transcript, academic summary, key takeaways, flashcards, and quiz for a completed lecture.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_lecture_audio_results_job_id
    ON public.lecture_audio_results (job_id);

CREATE INDEX IF NOT EXISTS idx_lecture_audio_results_course
    ON public.lecture_audio_results (course_id);

-- ─── 3. updated_at auto-trigger for lecture_audio_jobs ────────────────────────
CREATE OR REPLACE FUNCTION public.set_lecture_audio_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lecture_audio_jobs_updated_at ON public.lecture_audio_jobs;
CREATE TRIGGER trg_lecture_audio_jobs_updated_at
    BEFORE UPDATE ON public.lecture_audio_jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.set_lecture_audio_updated_at();

-- ─── 4. Security & Access Control Helper Functions ────────────────────────────

-- Check if user is the assigned instructor/teacher of the course or an admin
CREATE OR REPLACE FUNCTION public.is_authorized_course_teacher(p_course_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    -- 1. Admin bypass
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND role = 'admin') THEN
        RETURN TRUE;
    END IF;

    -- 2. Direct instructor on course
    IF EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND instructor_id = p_user_id) THEN
        RETURN TRUE;
    END IF;

    -- 3. Course member with teacher / ta role
    IF EXISTS (
        SELECT 1 FROM public.course_members
        WHERE course_id = p_course_id
          AND user_id = p_user_id
          AND role IN ('teacher', 'ta')
          AND is_active = true
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- Check if user can access a lecture audio job (teacher owner, enrolled student, or admin)
CREATE OR REPLACE FUNCTION public.can_access_lecture_audio(p_job_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_course_id UUID;
    v_teacher_id UUID;
    v_is_published BOOLEAN;
BEGIN
    SELECT course_id, teacher_id, is_published
    INTO v_course_id, v_teacher_id, v_is_published
    FROM public.lecture_audio_jobs
    WHERE id = p_job_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- 1. Teacher owner or Admin
    IF v_teacher_id = p_user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND role = 'admin') THEN
        RETURN TRUE;
    END IF;

    -- 2. Must be published for students
    IF NOT v_is_published THEN
        RETURN FALSE;
    END IF;

    -- 3. Enrolled active student in this course
    IF EXISTS (
        SELECT 1 FROM public.course_members
        WHERE course_id = v_course_id
          AND user_id = p_user_id
          AND is_active = true
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- ─── 5. Row Level Security ────────────────────────────────────────────────────
ALTER TABLE public.lecture_audio_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lecture_audio_results ENABLE ROW LEVEL SECURITY;

-- lecture_audio_jobs policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Teachers manage their own lecture audio jobs" ON public.lecture_audio_jobs;
    CREATE POLICY "Teachers manage their own lecture audio jobs"
        ON public.lecture_audio_jobs
        FOR ALL
        TO authenticated
        USING (auth.uid() = teacher_id)
        WITH CHECK (auth.uid() = teacher_id);

    DROP POLICY IF EXISTS "Authorized members view lecture audio jobs" ON public.lecture_audio_jobs;
    CREATE POLICY "Authorized members view lecture audio jobs"
        ON public.lecture_audio_jobs
        FOR SELECT
        TO authenticated
        USING (public.can_access_lecture_audio(id, auth.uid()));
END $$;

-- lecture_audio_results policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Authorized members view lecture audio results" ON public.lecture_audio_results;
    CREATE POLICY "Authorized members view lecture audio results"
        ON public.lecture_audio_results
        FOR SELECT
        TO authenticated
        USING (public.can_access_lecture_audio(job_id, auth.uid()));

    DROP POLICY IF EXISTS "Teachers delete lecture audio results" ON public.lecture_audio_results;
    CREATE POLICY "Teachers delete lecture audio results"
        ON public.lecture_audio_results
        FOR DELETE
        TO authenticated
        USING (EXISTS (
            SELECT 1 FROM public.lecture_audio_jobs j
            WHERE j.id = job_id AND j.teacher_id = auth.uid()
        ));
END $$;

-- ─── 6. RPC: get_orphaned_lecture_audio_jobs ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_orphaned_lecture_audio_jobs(p_older_than_hours INT DEFAULT 24)
RETURNS TABLE (
    job_id          UUID,
    teacher_id      UUID,
    course_id       UUID,
    storage_path    TEXT,
    status          TEXT,
    created_at      TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        id          AS job_id,
        teacher_id,
        course_id,
        storage_path,
        status,
        created_at
    FROM public.lecture_audio_jobs
    WHERE status IN ('queued', 'processing', 'transcribing', 'summarizing', 'generating', 'failed')
      AND created_at < (timezone('utc', now()) - (p_older_than_hours || ' hours')::interval)
    ORDER BY created_at ASC;
$$;

COMMENT ON FUNCTION public.get_orphaned_lecture_audio_jobs IS
    'Returns stale lecture audio processing jobs for automated retention cleanup.';

REVOKE ALL ON FUNCTION public.get_orphaned_lecture_audio_jobs FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_orphaned_lecture_audio_jobs TO service_role;
