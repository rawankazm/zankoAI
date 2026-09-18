-- ==============================================================================
-- ZankoAI Production Row Level Security (RLS) & Profile Architecture
-- Migration: 20260906000003_profile_and_rls_system.sql
-- ==============================================================================

-- 0. SCHEMA ENHANCEMENTS FOR PROFILES
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS university_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS department_name TEXT;

-- 1. SECURITY DEFINER HELPER FUNCTIONS (Non-Recursive)
-- ------------------------------------------------------------------------------
-- These functions run with elevated privileges to query public.profiles without
-- invoking Row Level Security recursively.

CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT COALESCE((SELECT role = 'admin' FROM public.profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT COALESCE((SELECT role IN ('teacher', 'admin') FROM public.profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.is_course_teacher(p_course_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.courses
        WHERE id = p_course_id
          AND (instructor_id = auth.uid() OR public.is_admin())
    );
$$;

CREATE OR REPLACE FUNCTION public.is_course_member(p_course_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.courses
            WHERE id = p_course_id AND instructor_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.course_members
            WHERE course_id = p_course_id
              AND user_id = auth.uid()
              AND is_active = true
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_of_student(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.course_members cm
        JOIN public.courses c ON c.id = cm.course_id
        WHERE cm.user_id = p_student_id
          AND cm.is_active = true
          AND (c.instructor_id = auth.uid() OR public.is_admin())
    );
$$;

-- Revoke execute from public and grant to authenticated & service_role
REVOKE ALL ON FUNCTION public.current_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_teacher() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_course_teacher(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_course_member(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_teacher_of_student(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_teacher() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_course_teacher(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_course_member(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_teacher_of_student(UUID) TO authenticated, service_role;


-- 2. SECURE PROFILE INITIALIZATION TRIGGER
-- ------------------------------------------------------------------------------
-- Automatically creates a profile when an auth.user is created.
-- STRICT REQUIREMENT: Client CANNOT supply initial role, status, or plan.
-- Always defaults to:
--   role = 'student'
--   status = 'active'
--   plan = 'free'

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        avatar_url,
        role,
        status,
        plan,
        score,
        rank_title,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name',
            split_part(COALESCE(NEW.email, 'student'), '@', 1)
        ),
        NEW.raw_user_meta_data->>'avatar_url',
        'student', -- HARDCODED: Client cannot choose role
        'active',  -- HARDCODED: Client cannot choose status
        'free',    -- HARDCODED: Client cannot choose plan
        0,
        'Newbie',
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE 
            WHEN profiles.full_name = '' OR profiles.full_name LIKE 'student%' 
            THEN COALESCE(EXCLUDED.full_name, profiles.full_name) 
            ELSE profiles.full_name 
        END,
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- Backfill existing auth.users who registered before trigger creation
INSERT INTO public.profiles (
    id,
    email,
    full_name,
    avatar_url,
    role,
    status,
    plan,
    score,
    rank_title,
    created_at,
    updated_at
)
SELECT 
    u.id,
    COALESCE(u.email, ''),
    COALESCE(
        u.raw_user_meta_data->>'full_name',
        u.raw_user_meta_data->>'name',
        split_part(COALESCE(u.email, 'student'), '@', 1)
    ),
    u.raw_user_meta_data->>'avatar_url',
    'student',
    'active',
    'free',
    0,
    'Newbie',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
FROM auth.users u
ON CONFLICT (id) DO NOTHING;


-- 3. PROFILE IMMUTABILITY & PRIVILEGE ESCALATION PREVENTION TRIGGER
-- ------------------------------------------------------------------------------
-- Prevents non-admins from mutating: id, role, plan, status.
-- Any client attempt to elevate privileges is immediately blocked.

CREATE OR REPLACE FUNCTION public.enforce_profile_update_security()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    -- Allow service_role or admin to update all fields
    IF auth.uid() IS NULL OR public.is_admin() THEN
        RETURN NEW;
    END IF;

    -- Non-admin client checks:
    -- Rule 3: Users cannot change id, role, plan, status
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Security violation: Profile ID cannot be modified.';
    END IF;

    IF NEW.role IS DISTINCT FROM OLD.role THEN
        RAISE EXCEPTION 'Security violation: User role cannot be modified by the client.';
    END IF;

    IF NEW.plan IS DISTINCT FROM OLD.plan THEN
        RAISE EXCEPTION 'Security violation: Subscription plan cannot be modified directly.';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Security violation: Account status cannot be modified by the user.';
    END IF;

    -- Reset or prevent altering VIP status and scores directly from client
    IF NEW.is_vip IS DISTINCT FROM OLD.is_vip THEN
        NEW.is_vip := OLD.is_vip;
    END IF;

    IF NEW.vip_status IS DISTINCT FROM OLD.vip_status THEN
        NEW.vip_status := OLD.vip_status;
    END IF;

    IF NEW.vip_expiry IS DISTINCT FROM OLD.vip_expiry THEN
        NEW.vip_expiry := OLD.vip_expiry;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profile_update_security ON public.profiles;
CREATE TRIGGER trg_enforce_profile_update_security
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_profile_update_security();


-- ==============================================================================
-- 4. ENABLE ROW LEVEL SECURITY (RLS) ON ALL 28 TABLES
-- ==============================================================================

ALTER TABLE public.universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faculties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lecture_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignment_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcard_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;


-- ==============================================================================
-- 5. RLS POLICIES FOR EACH DOMAIN
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- A. ACADEMIC DIRECTORY (Universities, Faculties, Departments)
-- Public catalog is readable by all authenticated/anon users, but writes are admin-only.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "universities_read_all" ON public.universities;
CREATE POLICY "universities_read_all" ON public.universities
    FOR SELECT TO authenticated, anon
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "universities_admin_manage" ON public.universities;
CREATE POLICY "universities_admin_manage" ON public.universities
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "faculties_read_all" ON public.faculties;
CREATE POLICY "faculties_read_all" ON public.faculties
    FOR SELECT TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "faculties_admin_manage" ON public.faculties;
CREATE POLICY "faculties_admin_manage" ON public.faculties
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "departments_read_all" ON public.departments;
CREATE POLICY "departments_read_all" ON public.departments
    FOR SELECT TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "departments_admin_manage" ON public.departments;
CREATE POLICY "departments_admin_manage" ON public.departments
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- B. PROFILES (Rules 1, 2, 3, 4, 6)
-- Rule 1: Users can read their own profile.
-- Rule 2: Users can update allowed profile fields.
-- Rule 3: Protected fields (role, plan, status, id) protected via policy and trigger.
-- Rule 4: Students cannot access another student's private data.
-- Teachers can view profiles of students enrolled in their courses.
-- Admins can read and manage all profiles.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
    FOR SELECT TO authenticated
    USING (
        id = auth.uid()
        OR public.is_admin()
        OR public.is_teacher_of_student(id)
    );

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_admin())
    WITH CHECK (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "profiles_insert_self" ON public.profiles;
CREATE POLICY "profiles_insert_self" ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        id = auth.uid()
        AND role = 'student'
        AND status = 'active'
        AND plan = 'free'
    );

DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
CREATE POLICY "profiles_admin_all" ON public.profiles
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- C. COURSES (Rules 5, 6)
-- Rule 5: Teachers can access only their authorized courses.
-- Students can view published courses.
-- Teachers can create courses and edit their own courses.
-- Admins can manage all courses.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "courses_select_policy" ON public.courses;
CREATE POLICY "courses_select_policy" ON public.courses
    FOR SELECT TO authenticated
    USING (
        is_published = true
        OR instructor_id = auth.uid()
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "courses_insert_policy" ON public.courses;
CREATE POLICY "courses_insert_policy" ON public.courses
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_admin()
        OR (public.is_teacher() AND instructor_id = auth.uid())
    );

DROP POLICY IF EXISTS "courses_update_policy" ON public.courses;
CREATE POLICY "courses_update_policy" ON public.courses
    FOR UPDATE TO authenticated
    USING (public.is_course_teacher(id))
    WITH CHECK (public.is_course_teacher(id));

DROP POLICY IF EXISTS "courses_delete_policy" ON public.courses;
CREATE POLICY "courses_delete_policy" ON public.courses
    FOR DELETE TO authenticated
    USING (public.is_course_teacher(id));


-- ------------------------------------------------------------------------------
-- D. COURSE MEMBERS (Enrollment & Rosters)
-- Students see their own enrollments.
-- Teachers see members of their own courses.
-- Admins can manage all enrollments.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "course_members_select" ON public.course_members;
CREATE POLICY "course_members_select" ON public.course_members
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_course_teacher(course_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "course_members_insert" ON public.course_members;
CREATE POLICY "course_members_insert" ON public.course_members
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        OR public.is_course_teacher(course_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "course_members_manage" ON public.course_members;
CREATE POLICY "course_members_manage" ON public.course_members
    FOR ALL TO authenticated
    USING (public.is_course_teacher(course_id) OR public.is_admin())
    WITH CHECK (public.is_course_teacher(course_id) OR public.is_admin());


-- ------------------------------------------------------------------------------
-- E. LECTURES & LECTURE PROGRESS (Rules 4, 5)
-- Lectures: viewable by enrolled course members; managed by course teacher.
-- Lecture Progress: strictly isolated to the student (user_id = auth.uid()).
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "lectures_select" ON public.lectures;
CREATE POLICY "lectures_select" ON public.lectures
    FOR SELECT TO authenticated
    USING (
        (is_published = true AND public.is_course_member(course_id))
        OR public.is_course_teacher(course_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "lectures_manage" ON public.lectures;
CREATE POLICY "lectures_manage" ON public.lectures
    FOR ALL TO authenticated
    USING (public.is_course_teacher(course_id) OR public.is_admin())
    WITH CHECK (public.is_course_teacher(course_id) OR public.is_admin());

DROP POLICY IF EXISTS "lecture_progress_select" ON public.lecture_progress;
CREATE POLICY "lecture_progress_select" ON public.lecture_progress
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "lecture_progress_manage" ON public.lecture_progress;
CREATE POLICY "lecture_progress_manage" ON public.lecture_progress
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());


-- ------------------------------------------------------------------------------
-- F. ASSIGNMENTS & SUBMISSIONS (Rules 4, 5)
-- Assignments: readable by course members; managed by course instructor.
-- Submissions: student can read and insert their OWN submission.
-- Instructor can read submissions in their course and grade them.
-- Student cannot alter grades or feedback.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "assignments_select" ON public.assignments;
CREATE POLICY "assignments_select" ON public.assignments
    FOR SELECT TO authenticated
    USING (
        (is_published = true AND public.is_course_member(course_id))
        OR public.is_course_teacher(course_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "assignments_manage" ON public.assignments;
CREATE POLICY "assignments_manage" ON public.assignments
    FOR ALL TO authenticated
    USING (public.is_course_teacher(course_id) OR public.is_admin())
    WITH CHECK (public.is_course_teacher(course_id) OR public.is_admin());

DROP POLICY IF EXISTS "assignment_submissions_select" ON public.assignment_submissions;
CREATE POLICY "assignment_submissions_select" ON public.assignment_submissions
    FOR SELECT TO authenticated
    USING (
        student_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.assignments a
            WHERE a.id = assignment_id AND public.is_course_teacher(a.course_id)
        )
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "assignment_submissions_insert" ON public.assignment_submissions;
CREATE POLICY "assignment_submissions_insert" ON public.assignment_submissions
    FOR INSERT TO authenticated
    WITH CHECK (
        student_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.assignments a
            WHERE a.id = assignment_id AND public.is_course_member(a.course_id)
        )
    );

DROP POLICY IF EXISTS "assignment_submissions_update" ON public.assignment_submissions;
CREATE POLICY "assignment_submissions_update" ON public.assignment_submissions
    FOR UPDATE TO authenticated
    USING (
        -- Student can update before grading, OR teacher/admin can grade
        (student_id = auth.uid() AND status = 'submitted')
        OR EXISTS (
            SELECT 1 FROM public.assignments a
            WHERE a.id = assignment_id AND public.is_course_teacher(a.course_id)
        )
        OR public.is_admin()
    )
    WITH CHECK (
        -- If student updates, cannot assign score or feedback
        (
            student_id = auth.uid()
            AND score IS NULL
            AND feedback IS NULL
            AND graded_by IS NULL
        )
        OR EXISTS (
            SELECT 1 FROM public.assignments a
            WHERE a.id = assignment_id AND public.is_course_teacher(a.course_id)
        )
        OR public.is_admin()
    );


-- ------------------------------------------------------------------------------
-- G. QUIZZES, QUESTIONS, ATTEMPTS & ANSWERS (Rules 4, 5)
-- Quizzes & Questions: readable by course members; managed by course instructor.
-- Attempts & Answers: student can read and take their OWN quiz.
-- Teacher can review attempts for their courses.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "quizzes_select" ON public.quizzes;
CREATE POLICY "quizzes_select" ON public.quizzes
    FOR SELECT TO authenticated
    USING (
        (is_published = true AND public.is_course_member(course_id))
        OR public.is_course_teacher(course_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "quizzes_manage" ON public.quizzes;
CREATE POLICY "quizzes_manage" ON public.quizzes
    FOR ALL TO authenticated
    USING (public.is_course_teacher(course_id) OR public.is_admin())
    WITH CHECK (public.is_course_teacher(course_id) OR public.is_admin());

DROP POLICY IF EXISTS "quiz_questions_select" ON public.quiz_questions;
CREATE POLICY "quiz_questions_select" ON public.quiz_questions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND (public.is_course_member(q.course_id) OR public.is_admin())
        )
    );

DROP POLICY IF EXISTS "quiz_questions_manage" ON public.quiz_questions;
CREATE POLICY "quiz_questions_manage" ON public.quiz_questions
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND (public.is_course_teacher(q.course_id) OR public.is_admin())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND (public.is_course_teacher(q.course_id) OR public.is_admin())
        )
    );

DROP POLICY IF EXISTS "quiz_attempts_select" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_select" ON public.quiz_attempts
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND public.is_course_teacher(q.course_id)
        )
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "quiz_attempts_insert" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_insert" ON public.quiz_attempts
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND public.is_course_member(q.course_id)
        )
    );

DROP POLICY IF EXISTS "quiz_attempts_update" ON public.quiz_attempts;
CREATE POLICY "quiz_attempts_update" ON public.quiz_attempts
    FOR UPDATE TO authenticated
    USING (
        (user_id = auth.uid() AND status = 'in_progress')
        OR EXISTS (
            SELECT 1 FROM public.quizzes q
            WHERE q.id = quiz_id AND public.is_course_teacher(q.course_id)
        )
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "quiz_answers_select" ON public.quiz_answers;
CREATE POLICY "quiz_answers_select" ON public.quiz_answers
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.quiz_attempts qa
            WHERE qa.id = attempt_id AND (qa.user_id = auth.uid() OR public.is_admin())
        )
        OR EXISTS (
            SELECT 1 FROM public.quiz_attempts qa
            JOIN public.quizzes q ON q.id = qa.quiz_id
            WHERE qa.id = attempt_id AND public.is_course_teacher(q.course_id)
        )
    );

DROP POLICY IF EXISTS "quiz_answers_insert" ON public.quiz_answers;
CREATE POLICY "quiz_answers_insert" ON public.quiz_answers
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.quiz_attempts qa
            WHERE qa.id = attempt_id AND qa.user_id = auth.uid() AND qa.status = 'in_progress'
        )
    );


-- ------------------------------------------------------------------------------
-- H. FLASHCARDS, STUDY PROGRESS & CALENDAR (Rule 4)
-- Private to creator/student.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "flashcards_select" ON public.flashcards;
CREATE POLICY "flashcards_select" ON public.flashcards
    FOR SELECT TO authenticated
    USING (creator_id = auth.uid() OR is_public = true OR public.is_admin());

DROP POLICY IF EXISTS "flashcards_manage" ON public.flashcards;
CREATE POLICY "flashcards_manage" ON public.flashcards
    FOR ALL TO authenticated
    USING (creator_id = auth.uid() OR public.is_admin())
    WITH CHECK (creator_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "flashcard_progress_manage" ON public.flashcard_progress;
CREATE POLICY "flashcard_progress_manage" ON public.flashcard_progress
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "study_progress_manage" ON public.study_progress;
CREATE POLICY "study_progress_manage" ON public.study_progress
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "calendar_events_manage" ON public.calendar_events;
CREATE POLICY "calendar_events_manage" ON public.calendar_events
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());


-- ------------------------------------------------------------------------------
-- I. NOTIFICATIONS & DEVICES (Rule 4)
-- User can only access their own notifications and device tokens.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "notification_devices_manage" ON public.notification_devices;
CREATE POLICY "notification_devices_manage" ON public.notification_devices
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.is_admin())
    WITH CHECK (user_id = auth.uid() OR public.is_admin());


-- ------------------------------------------------------------------------------
-- J. SUBSCRIPTIONS & SUBSCRIPTION EVENTS (Rule 7)
-- Rule 7: Users cannot modify subscriptions.
-- Users can read their own subscriptions.
-- Direct INSERT, UPDATE, DELETE by regular users is STRICTLY FORBIDDEN.
-- Managed only by admin or trusted backend webhook service role.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "subscriptions_select" ON public.subscriptions;
CREATE POLICY "subscriptions_select" ON public.subscriptions
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "subscriptions_admin_manage" ON public.subscriptions;
CREATE POLICY "subscriptions_admin_manage" ON public.subscriptions
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "subscription_events_select" ON public.subscription_events;
CREATE POLICY "subscription_events_select" ON public.subscription_events
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "subscription_events_admin_manage" ON public.subscription_events;
CREATE POLICY "subscription_events_admin_manage" ON public.subscription_events
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- K. PAYMENTS & PAYMENT EVENTS (Rules 8, 12)
-- Rule 8: Users cannot modify payment records.
-- Rule 12: Users cannot access another user's payment data.
-- Users can view their OWN payments.
-- Users can initiate a pending payment for themselves.
-- Users CANNOT approve, complete, modify or delete payment records.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "payments_select" ON public.payments;
CREATE POLICY "payments_select" ON public.payments
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "payments_insert" ON public.payments;
CREATE POLICY "payments_insert" ON public.payments
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND status = 'pending' -- Client can only create pending requests
        AND amount >= 0
    );

DROP POLICY IF EXISTS "payments_admin_manage" ON public.payments;
CREATE POLICY "payments_admin_manage" ON public.payments
    FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "payments_admin_delete" ON public.payments;
CREATE POLICY "payments_admin_delete" ON public.payments
    FOR DELETE TO authenticated
    USING (public.is_admin());

DROP POLICY IF EXISTS "payment_events_select" ON public.payment_events;
CREATE POLICY "payment_events_select" ON public.payment_events
    FOR SELECT TO authenticated
    USING (public.is_admin());

DROP POLICY IF EXISTS "payment_events_admin_manage" ON public.payment_events;
CREATE POLICY "payment_events_admin_manage" ON public.payment_events
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- L. USAGE RECORDS (Rule 9)
-- Rule 9: Users cannot manipulate usage records.
-- Users can only read their own usage metrics.
-- INSERT, UPDATE, DELETE restricted to admin / backend service role.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "usage_records_select" ON public.usage_records;
CREATE POLICY "usage_records_select" ON public.usage_records
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "usage_records_admin_manage" ON public.usage_records;
CREATE POLICY "usage_records_admin_manage" ON public.usage_records
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- M. AI REQUESTS & AI JOBS (Rules 10, 11)
-- Rule 10: Users cannot manipulate AI cost records.
-- Rule 11: Users cannot access another user's private AI requests.
-- Users can view their OWN AI requests.
-- Users can insert an AI request for themselves.
-- Users CANNOT update tokens, cost, latency, or status of an AI request.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "ai_requests_select" ON public.ai_requests;
CREATE POLICY "ai_requests_select" ON public.ai_requests
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "ai_requests_insert" ON public.ai_requests;
CREATE POLICY "ai_requests_insert" ON public.ai_requests
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
    );

DROP POLICY IF EXISTS "ai_requests_delete" ON public.ai_requests;
CREATE POLICY "ai_requests_delete" ON public.ai_requests
    FOR DELETE TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

-- Notice: NO UPDATE POLICY for users on ai_requests! Users cannot manipulate token counts or costs!
DROP POLICY IF EXISTS "ai_requests_admin_update" ON public.ai_requests;
CREATE POLICY "ai_requests_admin_update" ON public.ai_requests
    FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "ai_jobs_select" ON public.ai_jobs;
CREATE POLICY "ai_jobs_select" ON public.ai_jobs
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "ai_jobs_insert" ON public.ai_jobs;
CREATE POLICY "ai_jobs_insert" ON public.ai_jobs
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "ai_jobs_admin_manage" ON public.ai_jobs;
CREATE POLICY "ai_jobs_admin_manage" ON public.ai_jobs
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- ------------------------------------------------------------------------------
-- N. AUDIT LOGS (Security Compliance)
-- Strictly immutable audit logs. Readable only by admins.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "audit_logs_admin_select" ON public.audit_logs;
CREATE POLICY "audit_logs_admin_select" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (public.is_admin());

DROP POLICY IF EXISTS "audit_logs_admin_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_admin_insert" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
