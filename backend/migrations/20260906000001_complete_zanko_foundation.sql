-- ==============================================================================
-- ZankoAI Complete Supabase PostgreSQL Database Foundation
-- Migration File: 20260906000001_complete_zanko_foundation.sql
-- Single primary database: PostgreSQL on Supabase (ZERO Firebase)
-- Contains all 28 foundational tables, foreign keys, triggers, constraints & indexes
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. CLEAN RESET FOR ANY LEGACY/DRAFT TABLES
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.payment_events CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.ai_jobs CASCADE;
DROP TABLE IF EXISTS public.ai_requests CASCADE;
DROP TABLE IF EXISTS public.usage_records CASCADE;
DROP TABLE IF EXISTS public.subscription_events CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.notification_devices CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.calendar_events CASCADE;
DROP TABLE IF EXISTS public.study_progress CASCADE;
DROP TABLE IF EXISTS public.flashcard_progress CASCADE;
DROP TABLE IF EXISTS public.flashcards CASCADE;
DROP TABLE IF EXISTS public.quiz_answers CASCADE;
DROP TABLE IF EXISTS public.quiz_attempts CASCADE;
DROP TABLE IF EXISTS public.quiz_questions CASCADE;
DROP TABLE IF EXISTS public.quizzes CASCADE;
DROP TABLE IF EXISTS public.assignment_submissions CASCADE;
DROP TABLE IF EXISTS public.assignments CASCADE;
DROP TABLE IF EXISTS public.lecture_progress CASCADE;
DROP TABLE IF EXISTS public.lectures CASCADE;
DROP TABLE IF EXISTS public.course_members CASCADE;
DROP TABLE IF EXISTS public.courses CASCADE;
DROP TABLE IF EXISTS public.departments CASCADE;
DROP TABLE IF EXISTS public.faculties CASCADE;
DROP TABLE IF EXISTS public.universities CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;

-- 3. GLOBAL TRIGGER FUNCTION FOR updated_at
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 1. UNIVERSITIES
-- ==============================================================================
CREATE TABLE public.universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    name_ku TEXT,
    name_ar TEXT,
    code TEXT UNIQUE,
    logo_url TEXT,
    website TEXT,
    city TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'Iraq',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.universities IS 'Accredited universities and institutes in Kurdistan and Iraq';
COMMENT ON COLUMN public.universities.code IS 'Unique university acronym or code (e.g. SPU, EPU, UoD)';

-- ==============================================================================
-- 2. FACULTIES (Colleges within a University)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.faculties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID NOT NULL REFERENCES public.universities(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_ku TEXT,
    name_ar TEXT,
    code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_faculties_uni_name UNIQUE (university_id, name)
);

COMMENT ON TABLE public.faculties IS 'Colleges and academic faculties belonging to a university';

-- ==============================================================================
-- 3. DEPARTMENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_id UUID NOT NULL REFERENCES public.faculties(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_ku TEXT,
    name_ar TEXT,
    code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_departments_faculty_name UNIQUE (faculty_id, name)
);

COMMENT ON TABLE public.departments IS 'Academic departments offering degrees and courses';

-- ==============================================================================
-- 4. PROFILES (Users Core Identity)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
    university_id UUID REFERENCES public.universities(id) ON DELETE SET NULL,
    faculty_id UUID REFERENCES public.faculties(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
    phone TEXT,
    city_name TEXT,
    is_vip BOOLEAN NOT NULL DEFAULT false,
    vip_status TEXT NOT NULL DEFAULT 'none',
    vip_expiry TIMESTAMPTZ,
    bio TEXT,
    score INTEGER NOT NULL DEFAULT 0,
    rank_title TEXT NOT NULL DEFAULT 'Newbie',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.profiles IS 'Extended user profiles linked 1:1 with auth.users';
COMMENT ON COLUMN public.profiles.role IS 'User permission role: student, teacher, admin';
COMMENT ON COLUMN public.profiles.status IS 'Account status: active, suspended, deleted';
COMMENT ON COLUMN public.profiles.plan IS 'Billing plan: free, premium';

-- ==============================================================================
-- 5. COURSES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
    instructor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    title_ku TEXT,
    code TEXT NOT NULL,
    description TEXT,
    stage INTEGER NOT NULL DEFAULT 1 CHECK (stage BETWEEN 1 AND 6),
    semester INTEGER NOT NULL DEFAULT 1 CHECK (semester BETWEEN 1 AND 12),
    credits INTEGER NOT NULL DEFAULT 3 CHECK (credits > 0),
    cover_image_url TEXT,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_courses_dept_code UNIQUE (department_id, code)
);

COMMENT ON TABLE public.courses IS 'Academic courses taught within university departments';

-- ==============================================================================
-- 6. COURSE MEMBERS (Enrollments and Teaching Assignments)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.course_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'ta')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_course_members_course_user UNIQUE (course_id, user_id)
);

COMMENT ON TABLE public.course_members IS 'Membership and enrollment junction between users and courses';

-- ==============================================================================
-- 7. LECTURES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.lectures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    title_ku TEXT,
    content TEXT,
    file_url TEXT,
    file_type TEXT,
    file_size_bytes BIGINT,
    order_index INTEGER NOT NULL DEFAULT 0,
    duration_minutes INTEGER,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.lectures IS 'Syllabus lectures, chapters, presentation slides, and notes';

-- ==============================================================================
-- 8. LECTURE PROGRESS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.lecture_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL REFERENCES public.lectures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    progress_percent INTEGER NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    last_read_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_lecture_progress_lecture_user UNIQUE (lecture_id, user_id)
);

COMMENT ON TABLE public.lecture_progress IS 'Tracks student completion of individual lectures';

-- ==============================================================================
-- 9. ASSIGNMENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    due_date TIMESTAMPTZ NOT NULL,
    max_score NUMERIC(5,2) NOT NULL DEFAULT 100.00 CHECK (max_score > 0),
    attachment_url TEXT,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.assignments IS 'Course homework and project assignments';

-- ==============================================================================
-- 10. ASSIGNMENT SUBMISSIONS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.assignment_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT,
    file_url TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    score NUMERIC(5,2) CHECK (score >= 0),
    feedback TEXT,
    graded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    graded_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'graded', 'late', 'resubmitted')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_assignment_submission_student UNIQUE (assignment_id, student_id)
);

COMMENT ON TABLE public.assignment_submissions IS 'Student homework submissions and teacher grading';

-- ==============================================================================
-- 11. QUIZZES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    time_limit_minutes INTEGER NOT NULL DEFAULT 30 CHECK (time_limit_minutes > 0),
    passing_score NUMERIC(5,2) NOT NULL DEFAULT 50.00 CHECK (passing_score >= 0),
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.quizzes IS 'Tests, exams, and practice quizzes for courses';

-- ==============================================================================
-- 12. QUIZ QUESTIONS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type TEXT NOT NULL DEFAULT 'multiple_choice' CHECK (question_type IN ('multiple_choice', 'true_false', 'short_answer')),
    options JSONB NOT NULL DEFAULT '[]'::jsonb,
    correct_answer TEXT NOT NULL,
    explanation TEXT,
    points NUMERIC(5,2) NOT NULL DEFAULT 1.00 CHECK (points > 0),
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.quiz_questions IS 'Individual questions and options for quizzes';

-- ==============================================================================
-- 13. QUIZ ATTEMPTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    score NUMERIC(5,2) DEFAULT 0.00,
    total_points NUMERIC(5,2) DEFAULT 0.00,
    passed BOOLEAN DEFAULT false,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'timed_out')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.quiz_attempts IS 'User quiz test-taking sessions';

-- ==============================================================================
-- 14. QUIZ ANSWERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.quiz_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
    selected_answer TEXT,
    is_correct BOOLEAN NOT NULL DEFAULT false,
    points_awarded NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (points_awarded >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_quiz_answers_attempt_question UNIQUE (attempt_id, question_id)
);

COMMENT ON TABLE public.quiz_answers IS 'Specific answers provided by students during an attempt';

-- ==============================================================================
-- 15. FLASHCARDS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.flashcards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    deck_name TEXT NOT NULL DEFAULT 'General',
    front_text TEXT NOT NULL,
    back_text TEXT NOT NULL,
    hint TEXT,
    is_public BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.flashcards IS 'Study flashcard decks for quick memory retention';

-- ==============================================================================
-- 16. FLASHCARD PROGRESS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.flashcard_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    box INTEGER NOT NULL DEFAULT 1 CHECK (box BETWEEN 1 AND 5),
    ease_factor NUMERIC(3,2) NOT NULL DEFAULT 2.50 CHECK (ease_factor >= 1.30),
    interval_days INTEGER NOT NULL DEFAULT 1 CHECK (interval_days >= 0),
    repetitions INTEGER NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
    next_review_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_flashcard_progress_card_user UNIQUE (flashcard_id, user_id)
);

COMMENT ON TABLE public.flashcard_progress IS 'Spaced repetition (SM-2 / Leitner) progress per student card';

-- ==============================================================================
-- 17. STUDY PROGRESS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.study_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    total_lectures INTEGER NOT NULL DEFAULT 0 CHECK (total_lectures >= 0),
    completed_lectures INTEGER NOT NULL DEFAULT 0 CHECK (completed_lectures >= 0),
    total_quizzes INTEGER NOT NULL DEFAULT 0 CHECK (total_quizzes >= 0),
    completed_quizzes INTEGER NOT NULL DEFAULT 0 CHECK (completed_quizzes >= 0),
    completion_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (completion_rate BETWEEN 0.00 AND 100.00),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_study_progress_user_course UNIQUE (user_id, course_id)
);

COMMENT ON TABLE public.study_progress IS 'Aggregated course completion and academic momentum per student';

-- ==============================================================================
-- 18. CALENDAR EVENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    event_type TEXT NOT NULL DEFAULT 'reminder' CHECK (event_type IN ('exam', 'lecture', 'assignment', 'reminder', 'personal')),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_all_day BOOLEAN NOT NULL DEFAULT false,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_calendar_event_times CHECK (end_time >= start_time)
);

COMMENT ON TABLE public.calendar_events IS 'Schedule events, exam dates, lecture reminders, and study plans';

-- ==============================================================================
-- 19. NOTIFICATIONS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'system' CHECK (type IN ('system', 'broadcast', 'vip', 'academic', 'reminder', 'security')),
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.notifications IS 'User-directed in-app alerts and notifications';

-- ==============================================================================
-- 20. NOTIFICATION DEVICES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notification_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_id TEXT,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    app_version TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_notification_devices_token UNIQUE (fcm_token)
);

COMMENT ON TABLE public.notification_devices IS 'Registered user devices for WebPush, APNs, and FCM delivery';

-- ==============================================================================
-- 21. SUBSCRIPTIONS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL CHECK (plan_name IN ('free', 'vip_monthly', 'vip_yearly', 'vip_lifetime')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled', 'pending')),
    start_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    end_date TIMESTAMPTZ,
    auto_renew BOOLEAN NOT NULL DEFAULT false,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_active_user 
    ON public.subscriptions(user_id) 
    WHERE status = 'active';

COMMENT ON TABLE public.subscriptions IS 'VIP and premium membership subscriptions';

-- ==============================================================================
-- 22. SUBSCRIPTION EVENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('created', 'renewed', 'expired', 'cancelled', 'upgraded', 'downgraded')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.subscription_events IS 'Immutable lifecycle audit trail for subscription transitions';

-- ==============================================================================
-- 23. USAGE RECORDS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('ai_tokens', 'ai_requests', 'storage_bytes', 'presentation_exports', 'audio_transcriptions')),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_usage_period CHECK (period_end >= period_start)
);

COMMENT ON TABLE public.usage_records IS 'Per-user quota metering and billing consumption analytics';

-- ==============================================================================
-- 24. AI REQUESTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    model_name TEXT NOT NULL,
    feature TEXT NOT NULL CHECK (feature IN ('chat', 'presentation', 'quiz_generation', 'summarization', 'translation', 'ocr')),
    prompt_tokens INTEGER NOT NULL DEFAULT 0 CHECK (prompt_tokens >= 0),
    completion_tokens INTEGER NOT NULL DEFAULT 0 CHECK (completion_tokens >= 0),
    total_tokens INTEGER NOT NULL DEFAULT 0 CHECK (total_tokens >= 0),
    latency_ms INTEGER CHECK (latency_ms >= 0),
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.ai_requests IS 'Individual AI gateway interactions, prompt costs, and latency monitoring';

-- ==============================================================================
-- 25. AI JOBS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ai_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL CHECK (job_type IN ('presentation_builder', 'pdf_analysis', 'bulk_quiz_generator', 'transcription')),
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'cancelled')),
    input_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_result JSONB,
    progress_percent INTEGER NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    error_reason TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.ai_jobs IS 'Asynchronous background AI worker queue records';

-- ==============================================================================
-- 26. PAYMENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    gateway TEXT NOT NULL CHECK (gateway IN ('fib', 'fastpay', 'zaincash', 'manual', 'admin')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    currency TEXT NOT NULL DEFAULT 'IQD' CHECK (currency IN ('IQD', 'USD')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded', 'cancelled')),
    transaction_reference TEXT UNIQUE,
    receipt_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.payments IS 'Financial transactions processed via FIB, FastPay, ZainCash, or Manual Admin';

-- ==============================================================================
-- 27. PAYMENT EVENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('initiated', 'callback_received', 'verified', 'rejected', 'refunded')),
    raw_payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.payment_events IS 'Raw webhooks and callback payload logs for transaction auditing';

-- ==============================================================================
-- 28. AUDIT LOGS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    changes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.audit_logs IS 'System-wide immutable security audit and compliance log';

-- ==============================================================================
-- DATABASE INDEXES (Performance Optimization)
-- ==============================================================================

-- Universities & Hierarchy
CREATE INDEX IF NOT EXISTS idx_universities_city ON public.universities(city);
CREATE INDEX IF NOT EXISTS idx_faculties_uni_id ON public.faculties(university_id);
CREATE INDEX IF NOT EXISTS idx_departments_fac_id ON public.departments(faculty_id);

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_plan ON public.profiles(plan);
CREATE INDEX IF NOT EXISTS idx_profiles_uni_id ON public.profiles(university_id);
CREATE INDEX IF NOT EXISTS idx_profiles_dept_id ON public.profiles(department_id);

-- Courses & Members
CREATE INDEX IF NOT EXISTS idx_courses_dept_id ON public.courses(department_id);
CREATE INDEX IF NOT EXISTS idx_courses_instructor_id ON public.courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_stage_sem ON public.courses(stage, semester);
CREATE INDEX IF NOT EXISTS idx_course_members_course_id ON public.course_members(course_id);
CREATE INDEX IF NOT EXISTS idx_course_members_user_id ON public.course_members(user_id);

-- Lectures & Progress
CREATE INDEX IF NOT EXISTS idx_lectures_course_id ON public.lectures(course_id);
CREATE INDEX IF NOT EXISTS idx_lectures_order ON public.lectures(course_id, order_index);
CREATE INDEX IF NOT EXISTS idx_lecture_progress_user ON public.lecture_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_lecture_progress_lecture ON public.lecture_progress(lecture_id);

-- Assignments & Submissions
CREATE INDEX IF NOT EXISTS idx_assignments_course_id ON public.assignments(course_id);
CREATE INDEX IF NOT EXISTS idx_assignments_due_date ON public.assignments(due_date);
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_assign ON public.assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_student ON public.assignment_submissions(student_id);

-- Quizzes & Questions
CREATE INDEX IF NOT EXISTS idx_quizzes_course_id ON public.quizzes(course_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_id ON public.quiz_questions(quiz_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_id ON public.quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt_id ON public.quiz_answers(attempt_id);

-- Flashcards & Progress
CREATE INDEX IF NOT EXISTS idx_flashcards_course_id ON public.flashcards(course_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_creator_id ON public.flashcards(creator_id);
CREATE INDEX IF NOT EXISTS idx_flashcard_progress_user_review ON public.flashcard_progress(user_id, next_review_at);

-- Study Progress & Calendar
CREATE INDEX IF NOT EXISTS idx_study_progress_user_id ON public.study_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_study_progress_course_id ON public.study_progress(course_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_time ON public.calendar_events(user_id, start_time);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notification_devices_user ON public.notification_devices(user_id);

-- Subscriptions & Payments
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON public.subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_subscription_events_sub ON public.subscription_events(subscription_id);
CREATE INDEX IF NOT EXISTS idx_usage_records_user_period ON public.usage_records(user_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_ai_requests_user_created ON public.ai_requests(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status_created ON public.ai_jobs(status, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_user_status ON public.payments(user_id, status);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON public.payments(transaction_reference);
CREATE INDEX IF NOT EXISTS idx_payment_events_payment ON public.payment_events(payment_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created ON public.audit_logs(actor_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource_type, resource_id);

-- ==============================================================================
-- AUTOMATIC updated_at TRIGGERS
-- ==============================================================================
DO $$
DECLARE
    t text;
    tables text[] := ARRAY[
        'universities',
        'faculties',
        'departments',
        'profiles',
        'courses',
        'course_members',
        'lectures',
        'lecture_progress',
        'assignments',
        'assignment_submissions',
        'quizzes',
        'quiz_questions',
        'quiz_attempts',
        'flashcards',
        'flashcard_progress',
        'study_progress',
        'calendar_events',
        'notification_devices',
        'subscriptions',
        'ai_jobs',
        'payments'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated_at ON public.%I;', t, t);
        EXECUTE format('
            CREATE TRIGGER trg_%I_updated_at
            BEFORE UPDATE ON public.%I
            FOR EACH ROW
            EXECUTE FUNCTION public.set_current_timestamp_updated_at();
        ', t, t);
    END LOOP;
END $$;

-- ==============================================================================
-- AUTH -> PROFILES AUTOMATIC SYNC TRIGGER
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        avatar_url,
        role,
        status,
        plan
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(COALESCE(NEW.email, 'user'), '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
        'active',
        'free'
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- Grant permissions to authenticated & anon roles
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
