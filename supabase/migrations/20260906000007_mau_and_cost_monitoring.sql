-- ==============================================================================
-- ZankoAI Migration: Monthly Active User (MAU) Tracking & Supabase Cost Control
-- Description: Creates deduplicated daily activity log, DAU/MAU summaries,
--              configurable cost thresholds, and the get_admin_user_analytics RPC.
-- Migration Version: 20260906000007
-- ==============================================================================

-- 1. Deduplicated Daily User Activity (At most 1 row per user per day)
CREATE TABLE IF NOT EXISTS public.user_daily_activity (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id, activity_date)
);

COMMENT ON TABLE public.user_daily_activity IS 'Deduplicated daily activity log: at most 1 record per user per day to avoid raw event bloat';
COMMENT ON COLUMN public.user_daily_activity.activity_date IS 'UTC date of user activity';

-- Indexes for lightning fast range and roll-up queries
CREATE INDEX IF NOT EXISTS idx_user_daily_activity_date ON public.user_daily_activity (activity_date);
CREATE INDEX IF NOT EXISTS idx_user_daily_activity_date_role ON public.user_daily_activity (activity_date, role);
CREATE INDEX IF NOT EXISTS idx_user_daily_activity_date_plan ON public.user_daily_activity (activity_date, plan);
CREATE INDEX IF NOT EXISTS idx_user_daily_activity_user_date ON public.user_daily_activity (user_id, activity_date);

-- 2. Daily Active Users (DAU) Pre-Aggregated Summary
CREATE TABLE IF NOT EXISTS public.daily_active_users (
    date DATE PRIMARY KEY,
    unique_users INTEGER NOT NULL DEFAULT 0,
    active_students INTEGER NOT NULL DEFAULT 0,
    active_teachers INTEGER NOT NULL DEFAULT 0,
    new_users INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.daily_active_users IS 'Aggregated daily active user metrics computed by scheduled aggregation jobs';

-- 3. Monthly Active Users (MAU) Pre-Aggregated Summary
CREATE TABLE IF NOT EXISTS public.monthly_active_users (
    month DATE PRIMARY KEY, -- Truncated to first day of month (YYYY-MM-01)
    unique_users INTEGER NOT NULL DEFAULT 0,
    active_students INTEGER NOT NULL DEFAULT 0,
    active_teachers INTEGER NOT NULL DEFAULT 0,
    premium_users INTEGER NOT NULL DEFAULT 0,
    free_users INTEGER NOT NULL DEFAULT 0,
    total_registered INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.monthly_active_users IS 'Aggregated monthly active users (deduplicated across the entire month)';

-- 4. Supabase Cost & Scale Thresholds (Configurable alerts, NO auto-upgrades)
CREATE TABLE IF NOT EXISTS public.supabase_cost_thresholds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL, -- 'mau', 'database_size_mb', 'storage_size_gb', 'egress_gb', 'realtime_connections'
    threshold_value NUMERIC NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    is_triggered BOOLEAN NOT NULL DEFAULT false,
    last_triggered_at TIMESTAMPTZ,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_cost_threshold UNIQUE (metric_name, threshold_value)
);

COMMENT ON TABLE public.supabase_cost_thresholds IS 'Configurable cost and scale thresholds for monitoring Supabase quotas without surprise auto-upgrades';

-- Seed default initial thresholds
INSERT INTO public.supabase_cost_thresholds (metric_name, threshold_value, severity, description)
VALUES 
    ('mau', 50000, 'info', 'Supabase Free Tier MAU ceiling reached (50k MAU)'),
    ('mau', 75000, 'warning', 'Approaching Pro Tier capacity (75k MAU)'),
    ('mau', 90000, 'warning', '90% of Pro Tier included MAU reached (90k MAU)'),
    ('mau', 100000, 'critical', 'Pro Tier 100k MAU limit reached. Additional active users incur $0.00325/MAU'),
    ('database_size_mb', 400, 'warning', 'Database size reached 400 MB (80% of Free Tier 500 MB)'),
    ('database_size_mb', 7000, 'warning', 'Database size reached 7 GB (87% of Pro Tier 8 GB)'),
    ('storage_size_gb', 0.8, 'warning', 'Storage reached 800 MB (80% of Free Tier 1 GB)'),
    ('storage_size_gb', 80, 'warning', 'Storage reached 80 GB (80% of Pro Tier 100 GB)'),
    ('egress_gb', 1.8, 'warning', 'Monthly Egress reached 1.8 GB (90% of Free Tier 2 GB)'),
    ('egress_gb', 200, 'warning', 'Monthly Egress reached 200 GB (80% of Pro Tier 250 GB)')
ON CONFLICT (metric_name, threshold_value) DO NOTHING;

-- 5. System Cost Alerts Table
CREATE TABLE IF NOT EXISTS public.system_cost_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    current_value NUMERIC NOT NULL,
    threshold_value NUMERIC NOT NULL,
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    acknowledged BOOLEAN NOT NULL DEFAULT false,
    acknowledged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_system_cost_alerts_unacknowledged 
    ON public.system_cost_alerts (acknowledged, created_at DESC);

-- Enable RLS on all newly created tables
ALTER TABLE public.user_daily_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_active_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_active_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supabase_cost_thresholds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_cost_alerts ENABLE ROW LEVEL SECURITY;

-- Admins and service_role have full access
CREATE POLICY "Admins full access on user_daily_activity" ON public.user_daily_activity
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admins full access on daily_active_users" ON public.daily_active_users
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admins full access on monthly_active_users" ON public.monthly_active_users
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admins full access on supabase_cost_thresholds" ON public.supabase_cost_thresholds
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admins full access on system_cost_alerts" ON public.system_cost_alerts
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ==============================================================================
-- 6. STORED PROCEDURES & ATOMIC FUNCTIONS
-- ==============================================================================

-- A. Record User Activity (Invoked upon authenticated activity)
CREATE OR REPLACE FUNCTION public.record_user_activity(
    p_user_id UUID,
    p_role TEXT DEFAULT 'student',
    p_plan TEXT DEFAULT 'free'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_daily_activity (user_id, activity_date, role, plan, last_seen_at)
    VALUES (p_user_id, CURRENT_DATE, p_role, p_plan, timezone('utc'::text, now()))
    ON CONFLICT (user_id, activity_date)
    DO UPDATE SET 
        last_seen_at = timezone('utc'::text, now()),
        role = EXCLUDED.role,
        plan = EXCLUDED.plan;
END;
$$;

-- B. Aggregate Daily Active Users for a specific date
CREATE OR REPLACE FUNCTION public.aggregate_daily_active_users(
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_unique_users INTEGER;
    v_students INTEGER;
    v_teachers INTEGER;
    v_new_users INTEGER;
BEGIN
    -- Count unique active users for target date
    SELECT 
        COUNT(DISTINCT user_id),
        COUNT(DISTINCT CASE WHEN role = 'student' THEN user_id END),
        COUNT(DISTINCT CASE WHEN role = 'teacher' THEN user_id END)
    INTO v_unique_users, v_students, v_teachers
    FROM public.user_daily_activity
    WHERE activity_date = p_date;

    -- Count users registered on this date
    SELECT COUNT(*)
    INTO v_new_users
    FROM public.profiles
    WHERE created_at::DATE = p_date;

    -- Upsert daily summary
    INSERT INTO public.daily_active_users (date, unique_users, active_students, active_teachers, new_users, updated_at)
    VALUES (p_date, COALESCE(v_unique_users, 0), COALESCE(v_students, 0), COALESCE(v_teachers, 0), COALESCE(v_new_users, 0), timezone('utc'::text, now()))
    ON CONFLICT (date)
    DO UPDATE SET
        unique_users = EXCLUDED.unique_users,
        active_students = EXCLUDED.active_students,
        active_teachers = EXCLUDED.active_teachers,
        new_users = EXCLUDED.new_users,
        updated_at = timezone('utc'::text, now());
END;
$$;

-- C. Aggregate Monthly Active Users (Zero Double-Counting across entire month)
CREATE OR REPLACE FUNCTION public.aggregate_monthly_active_users(
    p_month DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE)::DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_start_date DATE := DATE_TRUNC('month', p_month)::DATE;
    v_end_date DATE := (DATE_TRUNC('month', p_month) + INTERVAL '1 month - 1 day')::DATE;
    v_unique_users INTEGER;
    v_students INTEGER;
    v_teachers INTEGER;
    v_premium INTEGER;
    v_free INTEGER;
    v_total_registered INTEGER;
BEGIN
    -- Strictly deduplicate users across all active days of the month
    SELECT 
        COUNT(DISTINCT user_id),
        COUNT(DISTINCT CASE WHEN role = 'student' THEN user_id END),
        COUNT(DISTINCT CASE WHEN role = 'teacher' THEN user_id END),
        COUNT(DISTINCT CASE WHEN plan = 'premium' THEN user_id END),
        COUNT(DISTINCT CASE WHEN plan = 'free' THEN user_id END)
    INTO v_unique_users, v_students, v_teachers, v_premium, v_free
    FROM public.user_daily_activity
    WHERE activity_date BETWEEN v_start_date AND v_end_date;

    -- Count total registered users up to the end of that month
    SELECT COUNT(*)
    INTO v_total_registered
    FROM public.profiles
    WHERE created_at <= (v_end_date + TIME '23:59:59');

    -- Upsert monthly summary
    INSERT INTO public.monthly_active_users (
        month, unique_users, active_students, active_teachers,
        premium_users, free_users, total_registered, updated_at
    )
    VALUES (
        v_start_date,
        COALESCE(v_unique_users, 0),
        COALESCE(v_students, 0),
        COALESCE(v_teachers, 0),
        COALESCE(v_premium, 0),
        COALESCE(v_free, 0),
        COALESCE(v_total_registered, 0),
        timezone('utc'::text, now())
    )
    ON CONFLICT (month)
    DO UPDATE SET
        unique_users = EXCLUDED.unique_users,
        active_students = EXCLUDED.active_students,
        active_teachers = EXCLUDED.active_teachers,
        premium_users = EXCLUDED.premium_users,
        free_users = EXCLUDED.free_users,
        total_registered = EXCLUDED.total_registered,
        updated_at = timezone('utc'::text, now());
END;
$$;

-- D. Check Cost & Usage Thresholds (Never auto-upgrades plans, records alerts)
CREATE OR REPLACE FUNCTION public.check_cost_and_usage_thresholds()
RETURNS TABLE (
    alert_created BOOLEAN,
    metric TEXT,
    val NUMERIC,
    threshold NUMERIC,
    alert_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_mau INTEGER;
    v_threshold RECORD;
BEGIN
    -- Calculate active users in the current calendar month
    SELECT COUNT(DISTINCT user_id)
    INTO v_current_mau
    FROM public.user_daily_activity
    WHERE activity_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE;

    -- Iterate through MAU thresholds
    FOR v_threshold IN 
        SELECT * FROM public.supabase_cost_thresholds 
        WHERE metric_name = 'mau' AND threshold_value <= v_current_mau
        ORDER BY threshold_value DESC
    LOOP
        -- Check if an unacknowledged alert for this threshold already exists
        IF NOT EXISTS (
            SELECT 1 FROM public.system_cost_alerts
            WHERE metric_name = 'mau' 
              AND threshold_value = v_threshold.threshold_value
              AND acknowledged = false
              AND created_at >= (timezone('utc'::text, now()) - INTERVAL '24 hours')
        ) THEN
            -- Insert alert record
            INSERT INTO public.system_cost_alerts (
                metric_name, current_value, threshold_value, severity, message
            )
            VALUES (
                'mau',
                v_current_mau,
                v_threshold.threshold_value,
                v_threshold.severity,
                format('MAU threshold reached: Current MAU (%s) has exceeded threshold (%s). Severity: %s.', 
                       v_current_mau, v_threshold.threshold_value, v_threshold.severity)
            );

            -- Mark threshold as triggered
            UPDATE public.supabase_cost_thresholds
            SET is_triggered = true, last_triggered_at = timezone('utc'::text, now())
            WHERE id = v_threshold.id;

            alert_created := true;
            metric := 'mau';
            val := v_current_mau;
            threshold := v_threshold.threshold_value;
            alert_message := format('Alert created for %s MAU', v_threshold.threshold_value);
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

-- E. High Performance RPC: get_admin_user_analytics
CREATE OR REPLACE FUNCTION public.get_admin_user_analytics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_registered INTEGER;
    v_daily_active INTEGER;
    v_monthly_active INTEGER;
    v_new_users_today INTEGER;
    v_new_users_this_month INTEGER;
    v_active_students INTEGER;
    v_active_teachers INTEGER;
    v_premium_users INTEGER;
    v_free_users INTEGER;
    v_alerts JSONB;
    v_current_month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
BEGIN
    -- 1. Total Registered Users
    SELECT COUNT(*) INTO v_total_registered FROM public.profiles;

    -- 2. Daily Active Users (Today)
    SELECT COUNT(DISTINCT user_id) INTO v_daily_active
    FROM public.user_daily_activity
    WHERE activity_date = CURRENT_DATE;

    -- 3. Monthly Active Users (Current Month - strictly deduplicated)
    SELECT 
        COUNT(DISTINCT user_id),
        COUNT(DISTINCT CASE WHEN role = 'student' THEN user_id END),
        COUNT(DISTINCT CASE WHEN role = 'teacher' THEN user_id END),
        COUNT(DISTINCT CASE WHEN plan = 'premium' THEN user_id END),
        COUNT(DISTINCT CASE WHEN plan = 'free' THEN user_id END)
    INTO 
        v_monthly_active,
        v_active_students,
        v_active_teachers,
        v_premium_users,
        v_free_users
    FROM public.user_daily_activity
    WHERE activity_date >= v_current_month_start;

    -- 4. New Registered Users
    SELECT COUNT(*) INTO v_new_users_today
    FROM public.profiles
    WHERE created_at::DATE = CURRENT_DATE;

    SELECT COUNT(*) INTO v_new_users_this_month
    FROM public.profiles
    WHERE created_at >= v_current_month_start;

    -- 5. Active Unacknowledged Cost/MAU Alerts
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'metric_name', metric_name,
        'current_value', current_value,
        'threshold_value', threshold_value,
        'severity', severity,
        'message', message,
        'created_at', created_at
    )), '[]'::jsonb)
    INTO v_alerts
    FROM public.system_cost_alerts
    WHERE acknowledged = false;

    -- Return JSON matching admin dashboard contract
    RETURN jsonb_build_object(
        'total_registered_users', COALESCE(v_total_registered, 0),
        'daily_active_users', COALESCE(v_daily_active, 0),
        'monthly_active_users', COALESCE(v_monthly_active, 0),
        'new_users', COALESCE(v_new_users_today, 0),
        'new_users_this_month', COALESCE(v_new_users_this_month, 0),
        'active_students', COALESCE(v_active_students, 0),
        'active_teachers', COALESCE(v_active_teachers, 0),
        'premium_users', COALESCE(v_premium_users, 0),
        'free_users', COALESCE(v_free_users, 0),
        'period', to_char(v_current_month_start, 'YYYY-MM'),
        'alerts', v_alerts,
        'generated_at', timezone('utc'::text, now())
    );
END;
$$;
