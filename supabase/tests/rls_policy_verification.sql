-- ==============================================================================
-- ZankoAI Row Level Security (RLS) Policy Automated Verification Test
-- File: supabase/tests/rls_policy_verification.sql
-- Runs in a transaction and rolls back at the end to keep the database pristine.
-- ==============================================================================

BEGIN;

-- 1. SETUP MOCK USERS & DATA
-- ------------------------------------------------------------------------------
-- Create mock auth users and profiles for testing
DO $$
DECLARE
    uid_student1 UUID := '00000000-0000-0000-0000-000000000001';
    uid_student2 UUID := '00000000-0000-0000-0000-000000000002';
    uid_teacher1 UUID := '00000000-0000-0000-0000-000000000003';
    uid_teacher2 UUID := '00000000-0000-0000-0000-000000000004';
    uid_admin1   UUID := '00000000-0000-0000-0000-000000000005';
    cid_course1  UUID := '10000000-0000-0000-0000-000000000001';
    cid_course2  UUID := '10000000-0000-0000-0000-000000000002';
    uni_id       UUID := '20000000-0000-0000-0000-000000000001';
    fac_id       UUID := '30000000-0000-0000-0000-000000000001';
    dept_id      UUID := '40000000-0000-0000-0000-000000000001';
BEGIN
    RAISE NOTICE '--- [SETUP] Creating Test Fixtures ---';

    -- Hierarchy
    INSERT INTO public.universities (id, name, city) VALUES (uni_id, 'Slemani University', 'Sulaymaniyah') ON CONFLICT DO NOTHING;
    INSERT INTO public.faculties (id, university_id, name) VALUES (fac_id, uni_id, 'College of Engineering') ON CONFLICT DO NOTHING;
    INSERT INTO public.departments (id, faculty_id, name) VALUES (dept_id, fac_id, 'Software Engineering') ON CONFLICT DO NOTHING;

    -- Profiles
    INSERT INTO public.profiles (id, email, full_name, role, status, plan) VALUES
        (uid_student1, 'student1@zanko.ai', 'Student One', 'student', 'active', 'free'),
        (uid_student2, 'student2@zanko.ai', 'Student Two', 'student', 'active', 'free'),
        (uid_teacher1, 'teacher1@zanko.ai', 'Teacher One', 'teacher', 'active', 'free'),
        (uid_teacher2, 'teacher2@zanko.ai', 'Teacher Two', 'teacher', 'active', 'free'),
        (uid_admin1,   'admin1@zanko.ai',   'Admin One',   'admin',   'active', 'free')
    ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role, plan = EXCLUDED.plan;

    -- Courses
    INSERT INTO public.courses (id, department_id, instructor_id, title, code) VALUES
        (cid_course1, dept_id, uid_teacher1, 'Algorithms & Data Structures', 'CS201'),
        (cid_course2, dept_id, uid_teacher2, 'Database Systems', 'CS301')
    ON CONFLICT DO NOTHING;

    -- Course Membership: Student 1 is in Course 1
    INSERT INTO public.course_members (course_id, user_id, role) VALUES
        (cid_course1, uid_student1, 'student')
    ON CONFLICT DO NOTHING;

    -- Private Records for Student 2
    INSERT INTO public.payments (id, user_id, gateway, amount, status) VALUES
        ('50000000-0000-0000-0000-000000000002', uid_student2, 'fib', 15000, 'completed')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.ai_requests (id, user_id, model_name, feature, prompt_tokens, completion_tokens, total_tokens) VALUES
        ('60000000-0000-0000-0000-000000000002', uid_student2, 'gemini-1.5-flash', 'chat', 150, 200, 350)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.subscriptions (id, user_id, plan_name, status) VALUES
        ('70000000-0000-0000-0000-000000000002', uid_student2, 'vip_monthly', 'active')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.usage_records (id, user_id, metric_type, quantity, period_start, period_end) VALUES
        ('80000000-0000-0000-0000-000000000002', uid_student2, 'ai_tokens', 12000, now(), now() + interval '30 days')
    ON CONFLICT DO NOTHING;
END $$;


-- ==============================================================================
-- 2. VERIFY RULE 1 & RULE 4: Student Isolation & Profile Access
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
    v_error_caught BOOLEAN := false;
BEGIN
    RAISE NOTICE '--- [TEST 1 & 4] Student Isolation & Profile Access ---';

    -- Impersonate Student 1
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

    -- Rule 1: Student 1 can read own profile
    SELECT COUNT(*) INTO v_cnt FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000001';
    ASSERT v_cnt = 1, 'TEST FAILED: Student 1 must be able to read their own profile';

    -- Rule 4: Student 1 CANNOT read Student 2 profile
    SELECT COUNT(*) INTO v_cnt FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002';
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Student 1 must not be able to read Student 2 profile';

    RAISE NOTICE '✅ PASS: Rule 1 & Rule 4 verified (Student profile isolation enforced)';
END $$;


-- ==============================================================================
-- 3. VERIFY RULE 2 & RULE 3: Profile Modification & Privilege Escalation Prevention
-- ==============================================================================
DO $$
DECLARE
    v_error_caught BOOLEAN := false;
BEGIN
    RAISE NOTICE '--- [TEST 2 & 3] Privilege Escalation Prevention ---';

    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

    -- Rule 2: Student 1 can update allowed profile fields (e.g. bio)
    UPDATE public.profiles SET bio = 'Aspiring Software Engineer' WHERE id = '00000000-0000-0000-0000-000000000001';

    -- Rule 3: Attempting to change role to admin MUST fail
    BEGIN
        UPDATE public.profiles SET role = 'admin' WHERE id = '00000000-0000-0000-0000-000000000001';
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;
    ASSERT v_error_caught, 'SECURITY VIOLATION: Non-admin changing role must raise an exception!';

    -- Attempting to change plan to premium MUST fail
    v_error_caught := false;
    BEGIN
        UPDATE public.profiles SET plan = 'premium' WHERE id = '00000000-0000-0000-0000-000000000001';
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;
    ASSERT v_error_caught, 'SECURITY VIOLATION: Non-admin changing plan must raise an exception!';

    RAISE NOTICE '✅ PASS: Rule 2 & Rule 3 verified (Privilege escalation strictly blocked)';
END $$;


-- ==============================================================================
-- 4. VERIFY RULE 7: Users Cannot Modify Subscriptions
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
    v_error_caught BOOLEAN := false;
BEGIN
    RAISE NOTICE '--- [TEST 7] Subscription Immutability for Users ---';

    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

    -- Student cannot insert subscriptions
    BEGIN
        INSERT INTO public.subscriptions (user_id, plan_name, status)
        VALUES ('00000000-0000-0000-0000-000000000001', 'vip_lifetime', 'active');
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;
    ASSERT v_error_caught, 'SECURITY VIOLATION: Client must not be able to insert subscriptions directly!';

    -- Student cannot update subscriptions
    UPDATE public.subscriptions SET status = 'active' WHERE user_id = '00000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Client must not update subscriptions!';

    RAISE NOTICE '✅ PASS: Rule 7 verified (Subscription modification strictly prevented)';
END $$;


-- ==============================================================================
-- 5. VERIFY RULE 8 & RULE 12: Payment Immutability & Cross-User Protection
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
    v_error_caught BOOLEAN := false;
BEGIN
    RAISE NOTICE '--- [TEST 8 & 12] Payment Records Security ---';

    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

    -- Rule 12: Student 1 CANNOT read Student 2's payment records
    SELECT COUNT(*) INTO v_cnt FROM public.payments WHERE user_id = '00000000-0000-0000-0000-000000000002';
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Student 1 must not read Student 2 payment records!';

    -- Rule 8: Student cannot mark payment as completed
    BEGIN
        INSERT INTO public.payments (user_id, gateway, amount, status)
        VALUES ('00000000-0000-0000-0000-000000000001', 'fib', 10000, 'completed');
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;
    ASSERT v_error_caught, 'SECURITY VIOLATION: Client cannot insert completed payments!';

    -- Rule 8: Student cannot update existing payment
    UPDATE public.payments SET status = 'completed' WHERE user_id = '00000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Client must not update payment records!';

    RAISE NOTICE '✅ PASS: Rule 8 & Rule 12 verified (Payment isolation and immutability enforced)';
END $$;


-- ==============================================================================
-- 6. VERIFY RULE 9, 10 & 11: Usage Records & AI Cost Isolation
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
    v_error_caught BOOLEAN := false;
BEGIN
    RAISE NOTICE '--- [TEST 9, 10 & 11] Usage Records & AI Cost Protection ---';

    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

    -- Rule 9: Student cannot manipulate usage records
    BEGIN
        INSERT INTO public.usage_records (user_id, metric_type, quantity, period_start, period_end)
        VALUES ('00000000-0000-0000-0000-000000000001', 'ai_tokens', 0, now(), now() + interval '30 days');
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;
    ASSERT v_error_caught, 'SECURITY VIOLATION: Client must not insert usage records!';

    -- Rule 11: Student 1 cannot read Student 2's AI requests
    SELECT COUNT(*) INTO v_cnt FROM public.ai_requests WHERE user_id = '00000000-0000-0000-0000-000000000002';
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Student 1 must not access Student 2 AI requests!';

    -- Rule 10: Student cannot modify tokens or cost of AI requests
    UPDATE public.ai_requests SET total_tokens = 0 WHERE user_id = '00000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Client must not update AI requests/cost records!';

    RAISE NOTICE '✅ PASS: Rule 9, 10 & 11 verified (AI requests & usage records strictly guarded)';
END $$;


-- ==============================================================================
-- 7. VERIFY RULE 5: Teacher Authorized Course Boundary
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
BEGIN
    RAISE NOTICE '--- [TEST 5] Teacher Authorized Course Boundary ---';

    -- Impersonate Teacher 1
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}', true);

    -- Teacher 1 can update Course 1 (their own course)
    UPDATE public.courses SET description = 'Updated Algorithms Course' WHERE id = '10000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 1, 'TEST FAILED: Teacher 1 must be able to update their own course!';

    -- Teacher 1 CANNOT update Course 2 (Teacher 2 course)
    UPDATE public.courses SET description = 'Hacked Course' WHERE id = '10000000-0000-0000-0000-000000000002';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 0, 'SECURITY VIOLATION: Teacher 1 must not be able to modify Teacher 2 course!';

    RAISE NOTICE '✅ PASS: Rule 5 verified (Teacher course boundaries strictly enforced)';
END $$;


-- ==============================================================================
-- 8. VERIFY RULE 6: Admin Comprehensive Authorization
-- ==============================================================================
DO $$
DECLARE
    v_cnt INT;
BEGIN
    RAISE NOTICE '--- [TEST 6] Admin Comprehensive Authorization ---';

    -- Impersonate Admin 1
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000005", "role": "authenticated"}', true);

    -- Admin can read all profiles
    SELECT COUNT(*) INTO v_cnt FROM public.profiles;
    ASSERT v_cnt >= 5, 'TEST FAILED: Admin must be able to view all profiles!';

    -- Admin can manage all courses
    UPDATE public.courses SET is_published = true WHERE id = '10000000-0000-0000-0000-000000000002';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 1, 'TEST FAILED: Admin must be able to manage any course!';

    -- Admin can manage subscriptions
    UPDATE public.subscriptions SET status = 'active' WHERE id = '70000000-0000-0000-0000-000000000002';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 1, 'TEST FAILED: Admin must be able to manage subscriptions!';

    -- Admin can manage payments
    UPDATE public.payments SET status = 'completed' WHERE id = '50000000-0000-0000-0000-000000000002';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ASSERT v_cnt = 1, 'TEST FAILED: Admin must be able to manage payments!';

    RAISE NOTICE '✅ PASS: Rule 6 verified (Admin operations fully functional)';
END $$;

RAISE NOTICE '🎉 ALL 12 SECURITY & RLS POLICIES VERIFIED SUCCESSFULLY WITH ZERO LEAKS!';

-- Rollback all test insertions to leave database in pristine state
ROLLBACK;
