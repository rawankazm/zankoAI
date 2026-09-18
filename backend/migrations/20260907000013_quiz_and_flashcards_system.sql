-- ==============================================================================
-- ZankoAI Migration: Complete Quiz and Flashcard System
-- Migration ID: 20260907000013_quiz_and_flashcards_system.sql
-- ==============================================================================

-- 1. Allow personal & AI study quizzes (course_id optional) and add metadata columns
ALTER TABLE IF EXISTS public.quizzes 
    ALTER COLUMN course_id DROP NOT NULL;

ALTER TABLE IF EXISTS public.quizzes
    ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'manual' 
        CHECK (source_type IN ('pdf', 'ocr', 'lecture', 'teacher', 'ai_topic', 'manual')),
    ADD COLUMN IF NOT EXISTS source_id UUID,
    ADD COLUMN IF NOT EXISTS difficulty TEXT NOT NULL DEFAULT 'medium' 
        CHECK (difficulty IN ('easy', 'medium', 'hard', 'advanced')),
    ADD COLUMN IF NOT EXISTS question_count INTEGER NOT NULL DEFAULT 0 CHECK (question_count >= 0);

-- 2. Enhance quiz_questions with difficulty and validation
ALTER TABLE IF EXISTS public.quiz_questions
    ADD COLUMN IF NOT EXISTS difficulty TEXT NOT NULL DEFAULT 'medium'
        CHECK (difficulty IN ('easy', 'medium', 'hard', 'advanced'));

-- Ensure question_type check constraint exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quiz_questions_type'
    ) THEN
        ALTER TABLE public.quiz_questions 
            DROP CONSTRAINT IF EXISTS quiz_questions_question_type_check;
        ALTER TABLE public.quiz_questions 
            ADD CONSTRAINT chk_quiz_questions_type 
            CHECK (question_type IN ('multiple_choice', 'true_false', 'short_answer'));
    END IF;
END $$;

-- 3. Enhance flashcards with source and difficulty
ALTER TABLE IF EXISTS public.flashcards
    ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'manual'
        CHECK (source_type IN ('pdf', 'ocr', 'lecture', 'teacher', 'ai_topic', 'manual')),
    ADD COLUMN IF NOT EXISTS source_id UUID,
    ADD COLUMN IF NOT EXISTS difficulty TEXT NOT NULL DEFAULT 'medium'
        CHECK (difficulty IN ('easy', 'medium', 'hard', 'advanced'));

-- 4. Enhance quiz_attempts for timer and answers summary
ALTER TABLE IF EXISTS public.quiz_attempts
    ADD COLUMN IF NOT EXISTS time_spent_seconds INTEGER DEFAULT 0 CHECK (time_spent_seconds >= 0),
    ADD COLUMN IF NOT EXISTS answers_summary JSONB DEFAULT '{}'::jsonb;

-- 5. Performance and Lookup Indexes
CREATE INDEX IF NOT EXISTS idx_quizzes_source ON public.quizzes(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_creator ON public.quizzes(creator_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_difficulty ON public.quizzes(difficulty);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_order ON public.quiz_questions(quiz_id, order_index);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_status ON public.quiz_attempts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_flashcards_user_deck ON public.flashcards(creator_id, deck_name);
CREATE INDEX IF NOT EXISTS idx_flashcards_progress_due ON public.flashcard_progress(user_id, next_review_at);

-- 6. Row Level Security Updates
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcard_progress ENABLE ROW LEVEL SECURITY;

-- Teachers can create quizzes for courses they instruct or general quizzes
DROP POLICY IF EXISTS "quizzes_teacher_insert" ON public.quizzes;
CREATE POLICY "quizzes_teacher_insert" ON public.quizzes
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = creator_id
    );

-- Users can view quizzes if public, course member, creator, or admin
DROP POLICY IF EXISTS "quizzes_view_authorized" ON public.quizzes;
CREATE POLICY "quizzes_view_authorized" ON public.quizzes
    FOR SELECT
    TO authenticated
    USING (
        creator_id = auth.uid()
        OR course_id IS NULL
        OR is_published = true
        OR EXISTS (
            SELECT 1 FROM public.course_members cm
            WHERE cm.course_id = quizzes.course_id AND cm.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role IN ('admin', 'superadmin')
        )
    );

-- Flashcard progress tracking policy: users own their progress records
DROP POLICY IF EXISTS "flashcard_progress_user_all" ON public.flashcard_progress;
CREATE POLICY "flashcard_progress_user_all" ON public.flashcard_progress
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE public.quizzes IS 'ZankoAI Quiz master records supporting course exams and AI-generated self-study';
COMMENT ON TABLE public.quiz_questions IS 'Validated questions with MCQ, True/False, and Short Answer types';
COMMENT ON TABLE public.quiz_attempts IS 'Server-scored student quiz attempts with timing and answer audit';
COMMENT ON TABLE public.flashcard_progress IS 'SM-2 spaced-repetition progress tracker per student and card';
