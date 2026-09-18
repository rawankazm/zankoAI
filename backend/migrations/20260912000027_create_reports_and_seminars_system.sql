-- ==============================================================================
-- ZankoAI Migration: Academic Reports & Seminars Backend System
-- Migration Version: 20260912000027_create_reports_and_seminars_system.sql
-- ==============================================================================

-- 1. Table: reports (Academic research reports)
CREATE TABLE IF NOT EXISTS public.reports (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title               TEXT            NOT NULL,
    subject             TEXT,
    topic               TEXT,
    language            VARCHAR(15)     NOT NULL DEFAULT 'ku', -- 'ku' (Sorani), 'badini', 'en', 'ar'
    description         TEXT,
    content             TEXT,                                  -- Full markdown / academic text
    student_name        TEXT,
    supervisor_name     TEXT,
    university_name     TEXT,
    department_name     TEXT,
    academic_year       VARCHAR(50),
    writing_style       VARCHAR(50)     NOT NULL DEFAULT 'academicComprehensive',
    length_level        VARCHAR(50)     NOT NULL DEFAULT 'words4000',
    logo_url            TEXT,
    status              VARCHAR(50)     NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('draft', 'processing', 'completed', 'failed', 'archived')),
    metadata            JSONB           NOT NULL DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.reports IS
    'Stores university-grade academic research reports generated and customized by students.';

-- 2. Table: report_sections (Ordered chapters/sections within reports)
CREATE TABLE IF NOT EXISTS public.report_sections (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id           UUID            NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
    section_order       INTEGER         NOT NULL,
    title               TEXT            NOT NULL,
    content             TEXT            NOT NULL,
    bullet_points       JSONB           NOT NULL DEFAULT '[]'::jsonb,
    page_number         INTEGER         NOT NULL DEFAULT 1,
    key_takeaway        TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.report_sections IS
    'Stores structured sections and chapters for academic reports.';

-- 3. Table: seminars (Academic seminar presentations)
CREATE TABLE IF NOT EXISTS public.seminars (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title               TEXT            NOT NULL,
    subject             TEXT,
    topic               TEXT,
    language            VARCHAR(15)     NOT NULL DEFAULT 'ku',
    description         TEXT,
    content             TEXT,                                  -- Raw generated outline / slide script
    status              VARCHAR(50)     NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('draft', 'processing', 'completed', 'failed', 'archived')),
    metadata            JSONB           NOT NULL DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.seminars IS
    'Stores university seminar presentations and slide decks.';

-- 4. Table: seminar_sections (Ordered presentation slides within seminars)
CREATE TABLE IF NOT EXISTS public.seminar_sections (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    seminar_id          UUID            NOT NULL REFERENCES public.seminars(id) ON DELETE CASCADE,
    section_order       INTEGER         NOT NULL,              -- 0-indexed slide index (0 to 7)
    title               TEXT            NOT NULL,
    content             TEXT,
    bullet_points       JSONB           NOT NULL DEFAULT '[]'::jsonb,
    speaker_notes       TEXT,
    visual_prompt       TEXT,
    image_url           TEXT,
    category_tag        TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now()),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.seminar_sections IS
    'Stores individual slide models, bullets, notes, and visual cues for seminar decks.';

-- 5. Table: academic_files (Attached assets, logos, and generated DOCX, PDF, PPTX exports)
CREATE TABLE IF NOT EXISTS public.academic_files (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    report_id           UUID            REFERENCES public.reports(id) ON DELETE CASCADE,
    seminar_id          UUID            REFERENCES public.seminars(id) ON DELETE CASCADE,
    file_type           VARCHAR(50)     NOT NULL CHECK (file_type IN ('docx', 'pdf', 'pptx', 'logo', 'image', 'other')),
    file_name           TEXT            NOT NULL,
    file_path           TEXT            NOT NULL,
    file_size           INTEGER,
    mime_type           VARCHAR(100),
    storage_bucket      VARCHAR(100)    NOT NULL DEFAULT 'academic-documents',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.academic_files IS
    'Tracks stored documents and exported files in Supabase Storage with strict ownership.';

-- 6. Performance & Search Indexes
CREATE INDEX IF NOT EXISTS idx_reports_user_created
    ON public.reports (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_status
    ON public.reports (status);

CREATE INDEX IF NOT EXISTS idx_report_sections_lookup
    ON public.report_sections (report_id, section_order ASC);

CREATE INDEX IF NOT EXISTS idx_seminars_user_created
    ON public.seminars (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_seminars_status
    ON public.seminars (status);

CREATE INDEX IF NOT EXISTS idx_seminar_sections_lookup
    ON public.seminar_sections (seminar_id, section_order ASC);

CREATE INDEX IF NOT EXISTS idx_academic_files_report
    ON public.academic_files (report_id) WHERE report_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_academic_files_seminar
    ON public.academic_files (seminar_id) WHERE seminar_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_academic_files_user
    ON public.academic_files (user_id, created_at DESC);

-- 7. Automated updated_at Triggers
CREATE OR REPLACE FUNCTION public.handle_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_reports_updated_at ON public.reports;
CREATE TRIGGER set_reports_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at_timestamp();

DROP TRIGGER IF EXISTS set_report_sections_updated_at ON public.report_sections;
CREATE TRIGGER set_report_sections_updated_at
    BEFORE UPDATE ON public.report_sections
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at_timestamp();

DROP TRIGGER IF EXISTS set_seminars_updated_at ON public.seminars;
CREATE TRIGGER set_seminars_updated_at
    BEFORE UPDATE ON public.seminars
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at_timestamp();

DROP TRIGGER IF EXISTS set_seminar_sections_updated_at ON public.seminar_sections;
CREATE TRIGGER set_seminar_sections_updated_at
    BEFORE UPDATE ON public.seminar_sections
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at_timestamp();

-- 8. Row Level Security (RLS)
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seminars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seminar_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_files ENABLE ROW LEVEL SECURITY;

-- Policies for reports
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own reports" ON public.reports;
    CREATE POLICY "Users can manage their own reports"
        ON public.reports
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Service role has full access to reports" ON public.reports;
    CREATE POLICY "Service role has full access to reports"
        ON public.reports
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;

-- Policies for report_sections
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can access sections of their own reports" ON public.report_sections;
    CREATE POLICY "Users can access sections of their own reports"
        ON public.report_sections
        FOR ALL
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.reports r
                WHERE r.id = report_sections.report_id
                  AND r.user_id = auth.uid()
            )
        )
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.reports r
                WHERE r.id = report_sections.report_id
                  AND r.user_id = auth.uid()
            )
        );

    DROP POLICY IF EXISTS "Service role has full access to report_sections" ON public.report_sections;
    CREATE POLICY "Service role has full access to report_sections"
        ON public.report_sections
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;

-- Policies for seminars
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own seminars" ON public.seminars;
    CREATE POLICY "Users can manage their own seminars"
        ON public.seminars
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Service role has full access to seminars" ON public.seminars;
    CREATE POLICY "Service role has full access to seminars"
        ON public.seminars
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;

-- Policies for seminar_sections
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can access slides of their own seminars" ON public.seminar_sections;
    CREATE POLICY "Users can access slides of their own seminars"
        ON public.seminar_sections
        FOR ALL
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.seminars s
                WHERE s.id = seminar_sections.seminar_id
                  AND s.user_id = auth.uid()
            )
        )
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.seminars s
                WHERE s.id = seminar_sections.seminar_id
                  AND s.user_id = auth.uid()
            )
        );

    DROP POLICY IF EXISTS "Service role has full access to seminar_sections" ON public.seminar_sections;
    CREATE POLICY "Service role has full access to seminar_sections"
        ON public.seminar_sections
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;

-- Policies for academic_files
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own academic files" ON public.academic_files;
    CREATE POLICY "Users can manage their own academic files"
        ON public.academic_files
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Service role has full access to academic_files" ON public.academic_files;
    CREATE POLICY "Service role has full access to academic_files"
        ON public.academic_files
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
END $$;

-- 9. Supabase Storage Bucket Initialization
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'academic-documents',
    'academic-documents',
    false, -- Private bucket
    52428800, -- 50 MB file size limit
    ARRAY[
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'image/png',
        'image/jpeg',
        'image/webp'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY[
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'image/png',
        'image/jpeg',
        'image/webp'
    ];

-- Storage Policies for 'academic-documents' bucket
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own academic documents" ON storage.objects;
    CREATE POLICY "Users can view their own academic documents"
        ON storage.objects
        FOR SELECT
        TO authenticated
        USING (
            bucket_id = 'academic-documents' AND
            (storage.foldername(name))[1] = auth.uid()::text
        );

    DROP POLICY IF EXISTS "Users can upload their own academic documents" ON storage.objects;
    CREATE POLICY "Users can upload their own academic documents"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (
            bucket_id = 'academic-documents' AND
            (storage.foldername(name))[1] = auth.uid()::text
        );

    DROP POLICY IF EXISTS "Users can update their own academic documents" ON storage.objects;
    CREATE POLICY "Users can update their own academic documents"
        ON storage.objects
        FOR UPDATE
        TO authenticated
        USING (
            bucket_id = 'academic-documents' AND
            (storage.foldername(name))[1] = auth.uid()::text
        )
        WITH CHECK (
            bucket_id = 'academic-documents' AND
            (storage.foldername(name))[1] = auth.uid()::text
        );

    DROP POLICY IF EXISTS "Users can delete their own academic documents" ON storage.objects;
    CREATE POLICY "Users can delete their own academic documents"
        ON storage.objects
        FOR DELETE
        TO authenticated
        USING (
            bucket_id = 'academic-documents' AND
            (storage.foldername(name))[1] = auth.uid()::text
        );
END $$;
