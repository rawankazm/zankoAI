-- ==============================================================================
-- ZankoAI Production-Grade Subscription & Server-Side Usage Limit System
-- Migration: 20260906000006_plan_limits_and_usage_system.sql
-- ==============================================================================

-- 1. Centralized, Configurable Plan Limits Table
CREATE TABLE IF NOT EXISTS public.plan_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan TEXT NOT NULL CHECK (plan IN ('free', 'premium')),
    feature TEXT NOT NULL,
    period_type TEXT NOT NULL CHECK (period_type IN ('daily', 'monthly')),
    limit_value BIGINT NOT NULL,
    fair_use_limit BIGINT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_plan_limits_plan_feature_period UNIQUE (plan, feature, period_type)
);

COMMENT ON TABLE public.plan_limits IS 'Authoritative matrix defining feature limits per plan (free vs premium). No hardcoded limits.';

-- 2. Usage Tracking Records Table
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature TEXT NOT NULL,
    period_type TEXT NOT NULL CHECK (period_type IN ('daily', 'monthly')),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    usage_count BIGINT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_usage_records_user_feature_period UNIQUE (user_id, feature, period_type, period_start)
);

COMMENT ON TABLE public.usage_records IS 'Server-side authoritative tracking of feature consumption over daily/monthly periods.';

-- 3. Idempotency Keys Table (Prevents double-counting expensive operations on client network retries)
CREATE TABLE IF NOT EXISTS public.usage_idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    idempotency_key TEXT NOT NULL,
    feature TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_usage_idempotency UNIQUE (user_id, idempotency_key)
);

COMMENT ON TABLE public.usage_idempotency_keys IS 'Tracks idempotent operation tokens to guarantee network retries do not double-count quota.';

-- Indexes for ultra-fast query execution and lock resolution
CREATE INDEX IF NOT EXISTS idx_plan_limits_lookup ON public.plan_limits (plan, feature) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_usage_records_user_feature ON public.usage_records (user_id, feature, period_start);
CREATE INDEX IF NOT EXISTS idx_usage_records_period ON public.usage_records (user_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_usage_idempotency_created ON public.usage_idempotency_keys (created_at);

-- 4. Initial Seed Data for Centralized Plan Limits
INSERT INTO public.plan_limits (plan, feature, period_type, limit_value, fair_use_limit, description)
VALUES
    -- FREE PLAN LIMITS (Initial Defaults, fully admin-configurable)
    ('free', 'ai_chat',    'daily',   10,         10,         'Free plan: 10 AI Chat requests per day'),
    ('free', 'pdf',        'monthly', 3,          3,          'Free plan: 3 PDF files per month'),
    ('free', 'ocr',        'monthly', 10,         10,         'Free plan: 10 OCR operations per month'),
    ('free', 'audio',      'monthly', 5,          5,          'Free plan: 5 Audio processing jobs per month'),
    ('free', 'homework',   'daily',   10,         10,         'Free plan: 10 Homework help requests per day'),
    ('free', 'quiz',       'monthly', 5,          5,          'Free plan: 5 AI Quiz generations per month'),
    ('free', 'flashcards', 'monthly', 5,          5,          'Free plan: 5 Flashcard sets generated per month'),
    ('free', 'storage',    'monthly', 52428800,   52428800,   'Free plan: 50MB storage limit in bytes'),

    -- PREMIUM PLAN LIMITS (Fair-use protection against infinite abuse)
    ('premium', 'ai_chat',    'daily',   500,        500,        'Premium plan: 500 AI Chat requests per day (fair use)'),
    ('premium', 'pdf',        'monthly', 100,        100,        'Premium plan: 100 PDF files per month (fair use)'),
    ('premium', 'ocr',        'monthly', 200,        200,        'Premium plan: 200 OCR operations per month (fair use)'),
    ('premium', 'audio',      'monthly', 100,        100,        'Premium plan: 100 Audio processing jobs per month (fair use)'),
    ('premium', 'homework',   'daily',   200,        200,        'Premium plan: 200 Homework requests per day (fair use)'),
    ('premium', 'quiz',       'monthly', 200,        200,        'Premium plan: 200 AI Quiz generations per month (fair use)'),
    ('premium', 'flashcards', 'monthly', 200,        200,        'Premium plan: 200 Flashcard sets per month (fair use)'),
    ('premium', 'storage',    'monthly', 5368709120, 5368709120, 'Premium plan: 5GB storage limit in bytes (fair use)')
ON CONFLICT (plan, feature, period_type) DO UPDATE SET
    limit_value = EXCLUDED.limit_value,
    fair_use_limit = EXCLUDED.fair_use_limit,
    updated_at = now();

-- 5. Atomic Quota Consumption Stored Procedure (SECURITY DEFINER)
-- Prevents race conditions with row-level locks (FOR UPDATE)
-- Enforces idempotency to avoid double counting on retries
-- Returns standard usage, limit, remaining, reset_at
CREATE OR REPLACE FUNCTION public.consume_feature_quota(
    p_user_id UUID,
    p_feature TEXT,
    p_increment BIGINT DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_plan TEXT := 'free';
    v_period_type TEXT := 'daily';
    v_limit BIGINT := 10;
    v_fair_use BIGINT := NULL;
    v_period_start TIMESTAMPTZ;
    v_period_end TIMESTAMPTZ;
    v_current_usage BIGINT := 0;
    v_new_usage BIGINT := 0;
    v_now TIMESTAMPTZ := clock_timestamp();
    v_record_id UUID;
    v_is_vip BOOLEAN := false;
BEGIN
    -- Step 1: Authoritative Plan Resolution from public.profiles
    SELECT 
        COALESCE(plan, 'free'),
        COALESCE(is_vip, false)
    INTO 
        v_user_plan,
        v_is_vip
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        -- Default to free if user profile is pending creation
        v_user_plan := 'free';
    END IF;

    -- Map any VIP status to premium plan
    IF v_is_vip THEN
        v_user_plan := 'premium';
    END IF;

    -- Step 2: Idempotency Key Check (Prevent double-counting on network retries)
    IF p_idempotency_key IS NOT NULL AND length(trim(p_idempotency_key)) > 0 THEN
        IF EXISTS (
            SELECT 1 FROM public.usage_idempotency_keys 
            WHERE user_id = p_user_id AND idempotency_key = p_idempotency_key
        ) THEN
            -- Idempotent replay: fetch current state without incrementing
            SELECT period_type INTO v_period_type
            FROM public.plan_limits
            WHERE plan = v_user_plan AND feature = p_feature AND is_active = true
            LIMIT 1;

            IF v_period_type = 'monthly' THEN
                v_period_start := date_trunc('month', v_now AT TIME ZONE 'UTC');
                v_period_end := v_period_start + INTERVAL '1 month';
            ELSE
                v_period_start := date_trunc('day', v_now AT TIME ZONE 'UTC');
                v_period_end := v_period_start + INTERVAL '1 day';
            END IF;

            SELECT COALESCE(usage_count, 0) INTO v_current_usage
            FROM public.usage_records
            WHERE user_id = p_user_id AND feature = p_feature 
              AND period_type = v_period_type AND period_start = v_period_start;

            SELECT limit_value INTO v_limit
            FROM public.plan_limits
            WHERE plan = v_user_plan AND feature = p_feature AND is_active = true
            LIMIT 1;

            RETURN jsonb_build_object(
                'allowed', true,
                'is_idempotent_replay', true,
                'plan', v_user_plan,
                'feature', p_feature,
                'current_usage', COALESCE(v_current_usage, 0),
                'limit', COALESCE(v_limit, 1000),
                'remaining', GREATEST(0, COALESCE(v_limit, 1000) - COALESCE(v_current_usage, 0)),
                'reset_at', v_period_end,
                'period_type', v_period_type
            );
        END IF;
    END IF;

    -- Step 3: Fetch Configured Limit from public.plan_limits
    SELECT 
        period_type,
        limit_value,
        fair_use_limit
    INTO 
        v_period_type,
        v_limit,
        v_fair_use
    FROM public.plan_limits
    WHERE plan = v_user_plan AND feature = p_feature AND is_active = true
    LIMIT 1;

    -- Safe fallbacks if feature is not explicitly configured
    IF NOT FOUND THEN
        IF v_user_plan = 'premium' THEN
            v_period_type := 'daily';
            v_limit := 500;
        ELSE
            v_period_type := 'daily';
            v_limit := 10;
        END IF;
    END IF;

    -- Step 4: Calculate Canonical UTC Period Window
    IF v_period_type = 'monthly' THEN
        v_period_start := date_trunc('month', v_now AT TIME ZONE 'UTC');
        v_period_end := v_period_start + INTERVAL '1 month';
    ELSE
        v_period_type := 'daily';
        v_period_start := date_trunc('day', v_now AT TIME ZONE 'UTC');
        v_period_end := v_period_start + INTERVAL '1 day';
    END IF;

    -- Step 5: Acquire Row-Level Lock or Insert Zero-Usage Record to Prevent Race Conditions
    INSERT INTO public.usage_records (
        user_id,
        feature,
        period_type,
        period_start,
        period_end,
        usage_count,
        metadata,
        updated_at
    )
    VALUES (
        p_user_id,
        p_feature,
        v_period_type,
        v_period_start,
        v_period_end,
        0,
        jsonb_build_object('initialized_at', v_now),
        v_now
    )
    ON CONFLICT (user_id, feature, period_type, period_start)
    DO NOTHING;

    -- Lock the specific row FOR UPDATE to serialize concurrent transactions
    SELECT id, usage_count
    INTO v_record_id, v_current_usage
    FROM public.usage_records
    WHERE user_id = p_user_id 
      AND feature = p_feature 
      AND period_type = v_period_type 
      AND period_start = v_period_start
    FOR UPDATE;

    -- Step 6: Enforce Limits
    IF (v_current_usage + p_increment) > v_limit THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'code', 'QUOTA_EXCEEDED',
            'plan', v_user_plan,
            'feature', p_feature,
            'current_usage', v_current_usage,
            'limit', v_limit,
            'remaining', 0,
            'reset_at', v_period_end,
            'period_type', v_period_type
        );
    END IF;

    -- Step 7: Atomically Increment Usage
    v_new_usage := v_current_usage + p_increment;
    UPDATE public.usage_records
    SET 
        usage_count = v_new_usage,
        updated_at = v_now
    WHERE id = v_record_id;

    -- Record Idempotency Key if supplied
    IF p_idempotency_key IS NOT NULL AND length(trim(p_idempotency_key)) > 0 THEN
        INSERT INTO public.usage_idempotency_keys (user_id, idempotency_key, feature, created_at)
        VALUES (p_user_id, p_idempotency_key, p_feature, v_now)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Step 8: Return Successful Result
    RETURN jsonb_build_object(
        'allowed', true,
        'is_idempotent_replay', false,
        'plan', v_user_plan,
        'feature', p_feature,
        'current_usage', v_new_usage,
        'limit', v_limit,
        'remaining', GREATEST(0, v_limit - v_new_usage),
        'reset_at', v_period_end,
        'period_type', v_period_type
    );
END;
$$;

-- 6. Complete Usage Status Query Function (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.get_user_usage_status(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_plan TEXT := 'free';
    v_is_vip BOOLEAN := false;
    v_now TIMESTAMPTZ := clock_timestamp();
    v_features JSONB := '{}'::jsonb;
    v_limit_rec RECORD;
    v_period_start TIMESTAMPTZ;
    v_period_end TIMESTAMPTZ;
    v_used BIGINT;
BEGIN
    SELECT COALESCE(plan, 'free'), COALESCE(is_vip, false)
    INTO v_user_plan, v_is_vip
    FROM public.profiles
    WHERE id = p_user_id;

    IF v_is_vip THEN
        v_user_plan := 'premium';
    END IF;

    FOR v_limit_rec IN
        SELECT feature, period_type, limit_value, fair_use_limit, description
        FROM public.plan_limits
        WHERE plan = v_user_plan AND is_active = true
        ORDER BY feature
    LOOP
        IF v_limit_rec.period_type = 'monthly' THEN
            v_period_start := date_trunc('month', v_now AT TIME ZONE 'UTC');
            v_period_end := v_period_start + INTERVAL '1 month';
        ELSE
            v_period_start := date_trunc('day', v_now AT TIME ZONE 'UTC');
            v_period_end := v_period_start + INTERVAL '1 day';
        END IF;

        SELECT COALESCE(usage_count, 0)
        INTO v_used
        FROM public.usage_records
        WHERE user_id = p_user_id
          AND feature = v_limit_rec.feature
          AND period_type = v_limit_rec.period_type
          AND period_start = v_period_start;

        IF v_used IS NULL THEN
            v_used := 0;
        END IF;

        v_features := jsonb_set(
            v_features,
            ARRAY[v_limit_rec.feature],
            jsonb_build_object(
                'feature', v_limit_rec.feature,
                'period_type', v_limit_rec.period_type,
                'current_usage', v_used,
                'limit', v_limit_rec.limit_value,
                'remaining', GREATEST(0, v_limit_rec.limit_value - v_used),
                'reset_at', v_period_end,
                'description', v_limit_rec.description
            )
        );
    END LOOP;

    RETURN jsonb_build_object(
        'plan', v_user_plan,
        'is_vip', v_is_vip,
        'features', v_features,
        'queried_at', v_now
    );
END;
$$;

-- 7. Row Level Security Policies
ALTER TABLE public.plan_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_idempotency_keys ENABLE ROW LEVEL SECURITY;

-- Plan Limits: Anyone authenticated can view limits; only admin can mutate
CREATE POLICY "Public and authenticated users can view active plan limits"
ON public.plan_limits FOR SELECT
USING (is_active = true);

CREATE POLICY "Admins can manage plan limits"
ON public.plan_limits FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Usage Records: Users can view their own usage history
CREATE POLICY "Users can view their own usage records"
ON public.usage_records FOR SELECT
USING (auth.uid() = user_id);

-- Idempotency Keys: Users can view their own idempotency keys
CREATE POLICY "Users can view their own idempotency keys"
ON public.usage_idempotency_keys FOR SELECT
USING (auth.uid() = user_id);

-- Cleanup job helper to prune expired idempotency keys (older than 7 days)
CREATE OR REPLACE FUNCTION public.cleanup_expired_idempotency_keys()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM public.usage_idempotency_keys
    WHERE created_at < (now() - INTERVAL '7 days');
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;
