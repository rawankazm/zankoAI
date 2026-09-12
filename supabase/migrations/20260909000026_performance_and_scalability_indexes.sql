-- ==============================================================================
-- ZankoAI Production Database Performance & Scalability Indexes
-- Migration: 20260909000025_performance_and_scalability_indexes.sql
-- ==============================================================================

-- 1. Courses Multi-Column Filtering & Code Lookup Indexes
-- Covers high-frequency queries: department + stage + semester + published status
CREATE INDEX IF NOT EXISTS idx_courses_perf_filter 
    ON public.courses(department_id, stage, semester, is_published);

CREATE INDEX IF NOT EXISTS idx_courses_code_lookup 
    ON public.courses(code);

-- 2. Academic Hierarchy Directory Indexes
CREATE INDEX IF NOT EXISTS idx_universities_name_city 
    ON public.universities(name, city);

CREATE INDEX IF NOT EXISTS idx_departments_faculty_name 
    ON public.departments(faculty_id, name);

CREATE INDEX IF NOT EXISTS idx_faculties_uni_name 
    ON public.faculties(university_id, name);

-- 3. Lectures Performance Indexes
CREATE INDEX IF NOT EXISTS idx_lectures_course_published 
    ON public.lectures(course_id, is_published, order_index);

-- 4. Unique Exam Results Constraint / Index for Zero Race Conditions
CREATE UNIQUE INDEX IF NOT EXISTS idx_exam_results_course_student 
    ON public.exam_results(course_id, student_id);

-- 5. Course Memberships Active & Chronological Indexes
CREATE INDEX IF NOT EXISTS idx_course_members_active_joined 
    ON public.course_members(course_id, is_active, joined_at DESC);

-- 6. Notifications Categorical & Temporal Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_type_created 
    ON public.notifications(user_id, type, created_at DESC);

-- 7. Device Tokens Active State Index
CREATE INDEX IF NOT EXISTS idx_notification_devices_active 
    ON public.notification_devices(user_id, is_active, updated_at DESC);

-- 8. Calendar Events Time Range Filtering Index
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_range 
    ON public.calendar_events(user_id, start_time, end_time);

-- 9. Centralized Usage Tracking Index
CREATE INDEX IF NOT EXISTS idx_user_usage_lookup 
    ON public.user_usage(user_id, feature, date);

-- 10. AI Conversations Temporal Order Index
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_updated 
    ON public.ai_conversations(user_id, updated_at DESC);

-- 11. Subscription Maintenance Batch Query Index
CREATE INDEX IF NOT EXISTS idx_subscriptions_status_expires 
    ON public.subscriptions(status, expires_at);
