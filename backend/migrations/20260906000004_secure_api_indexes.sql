-- ==============================================================================
-- ZankoAI Secure Data API Production Indexes
-- Migration: 20260906000004_secure_api_indexes.sql
-- ==============================================================================

-- 1. Academic Structure Indexes
CREATE INDEX IF NOT EXISTS idx_faculties_uni ON public.faculties(university_id);
CREATE INDEX IF NOT EXISTS idx_departments_faculty ON public.departments(faculty_id);
CREATE INDEX IF NOT EXISTS idx_courses_department ON public.courses(department_id);
CREATE INDEX IF NOT EXISTS idx_courses_instructor ON public.courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_stage_semester ON public.courses(stage, semester);

-- 2. Course Membership & Fast Enrollment Check Index
CREATE INDEX IF NOT EXISTS idx_course_members_lookup ON public.course_members(course_id, user_id, role);
CREATE INDEX IF NOT EXISTS idx_course_members_user ON public.course_members(user_id);

-- 3. Learning Domain (Lectures, Progress, Assignments, Submissions)
CREATE INDEX IF NOT EXISTS idx_lectures_course_order ON public.lectures(course_id, order_index);
CREATE INDEX IF NOT EXISTS idx_lecture_progress_user_lec ON public.lecture_progress(user_id, lecture_id);

CREATE INDEX IF NOT EXISTS idx_assignments_course_due ON public.assignments(course_id, due_date);
CREATE INDEX IF NOT EXISTS idx_submissions_assignment_student ON public.assignment_submissions(assignment_id, student_id);

-- 4. Quizzes & Attempts
CREATE INDEX IF NOT EXISTS idx_quizzes_course ON public.quizzes(course_id, is_published);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON public.quiz_questions(quiz_id, order_index);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_user ON public.quiz_attempts(quiz_id, user_id);

-- 5. Flashcards & Progress
CREATE INDEX IF NOT EXISTS idx_flashcards_creator_deck ON public.flashcards(creator_id, deck_name);
CREATE INDEX IF NOT EXISTS idx_flashcard_progress_next ON public.flashcard_progress(user_id, next_review_at);

-- 6. Calendar & Study Progress
CREATE INDEX IF NOT EXISTS idx_calendar_user_time ON public.calendar_events(user_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_study_progress_user_course ON public.study_progress(user_id, course_id);

-- 7. Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read, created_at DESC);
