-- ==============================================================================
-- ZankoAI Migration: AI Cost Protection, Request Telemetry, and Spending Guardrails
-- Migration Version: 20260908000021_ai_cost_control_and_guardrails.sql
-- ==============================================================================

-- 1. Ensure public.ai_requests table exists with full schema
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature VARCHAR(50) NOT NULL DEFAULT 'ai_chat',
    provider VARCHAR(50) NOT NULL DEFAULT 'google',
    model VARCHAR(100) NOT NULL DEFAULT 'gemini-2.5-flash',
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    estimated_cost NUMERIC(10, 6) NOT NULL DEFAULT 0.000000,
    duration INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'success',
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Ensure all required columns exist if table was previously created with older schema
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS feature VARCHAR(50) DEFAULT 'ai_chat';
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS provider VARCHAR(50) DEFAULT 'google';
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS model VARCHAR(100) DEFAULT 'gemini-2.5-flash';
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS input_tokens INTEGER DEFAULT 0;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS output_tokens INTEGER DEFAULT 0;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS estimated_cost NUMERIC(10, 6) DEFAULT 0.000000;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS duration INTEGER DEFAULT 0;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'success';
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS error_message TEXT;
ALTER TABLE public.ai_requests ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Convert legacy status values (e.g., 'completed' -> 'success') before enforcing check constraint
UPDATE public.ai_requests 
SET status = 'success' 
WHERE status = 'completed';

UPDATE public.ai_requests 
SET status = 'failed' 
WHERE status NOT IN ('success', 'failed', 'timeout', 'blocked');

-- Allow 'blocked' status in ai_requests for budget and concurrency cutoffs
ALTER TABLE public.ai_requests DROP CONSTRAINT IF EXISTS ai_requests_status_check;
ALTER TABLE public.ai_requests ADD CONSTRAINT ai_requests_status_check 
    CHECK (status IN ('success', 'failed', 'timeout', 'blocked'));

-- Synchronize legacy column data safely if prompt_tokens or completion_tokens columns exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'ai_requests' AND column_name = 'prompt_tokens'
    ) THEN
        EXECUTE 'UPDATE public.ai_requests SET input_tokens = prompt_tokens WHERE (input_tokens IS NULL OR input_tokens = 0) AND prompt_tokens > 0';
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'ai_requests' AND column_name = 'completion_tokens'
    ) THEN
        EXECUTE 'UPDATE public.ai_requests SET output_tokens = completion_tokens WHERE (output_tokens IS NULL OR output_tokens = 0) AND completion_tokens > 0';
    END IF;
END $$;

-- 2. Configurable AI Cost & Concurrency Limits Table
CREATE TABLE IF NOT EXISTS public.ai_cost_limits (
    plan TEXT PRIMARY KEY CHECK (plan IN ('free', 'premium')),
    max_request_chars INTEGER NOT NULL,
    max_tokens INTEGER NOT NULL,
    max_daily_cost_usd NUMERIC(10, 4) NOT NULL,
    max_monthly_cost_usd NUMERIC(10, 4) NOT NULL,
    max_concurrent_jobs INTEGER NOT NULL,
    rate_limit_per_min INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ai_cost_limits IS 'Authoritative configuration for AI cost, payload size, tokens, concurrency, and rate limits per tier.';

-- 3. Seed Configurable Limits for Free and Premium
INSERT INTO public.ai_cost_limits (
    plan,
    max_request_chars,
    max_tokens,
    max_daily_cost_usd,
    max_monthly_cost_usd,
    max_concurrent_jobs,
    rate_limit_per_min,
    description
) VALUES
(
    'free',
    3000,
    1000,
    0.0500,
    0.5000,
    1,
    10,
    'Free tier: 3,000 char prompt, 1,000 max tokens, $0.05/day budget, $0.50/month budget, 1 concurrent job, 10 req/min'
),
(
    'premium',
    20000,
    4000,
    2.0000,
    20.0000,
    5,
    60,
    'Premium tier: 20,000 char prompt, 4,000 max tokens, $2.00/day budget, $20.00/month budget, 5 concurrent jobs, 60 req/min'
)
ON CONFLICT (plan) DO UPDATE SET
    max_request_chars = EXCLUDED.max_request_chars,
    max_tokens = EXCLUDED.max_tokens,
    max_daily_cost_usd = EXCLUDED.max_daily_cost_usd,
    max_monthly_cost_usd = EXCLUDED.max_monthly_cost_usd,
    max_concurrent_jobs = EXCLUDED.max_concurrent_jobs,
    rate_limit_per_min = EXCLUDED.rate_limit_per_min,
    description = EXCLUDED.description,
    updated_at = now();

-- 4. Dedicated AI Spending Alerts Table
CREATE TABLE IF NOT EXISTS public.ai_spending_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    alert_type VARCHAR(50) NOT NULL, -- 'user_daily_threshold', 'user_monthly_threshold', 'system_daily_threshold', 'abuse_blocked'
    threshold_value NUMERIC(10, 4) NOT NULL,
    current_value NUMERIC(10, 4) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    message TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    acknowledged BOOLEAN NOT NULL DEFAULT false,
    acknowledged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ai_spending_alerts IS 'Alerts triggered when users or system approach or exceed AI cost thresholds or trigger abuse protection.';

-- 5. Performance Indexes for Real-time Aggregation & Monitoring
CREATE INDEX IF NOT EXISTS idx_ai_requests_cost_date 
    ON public.ai_requests (created_at DESC, estimated_cost);

CREATE INDEX IF NOT EXISTS idx_ai_requests_user_date_cost 
    ON public.ai_requests (user_id, created_at DESC, estimated_cost);

CREATE INDEX IF NOT EXISTS idx_ai_requests_feature_status 
    ON public.ai_requests (feature, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_spending_alerts_ack 
    ON public.ai_spending_alerts (acknowledged, created_at DESC);

-- 6. Row Level Security Policies
ALTER TABLE public.ai_cost_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_spending_alerts ENABLE ROW LEVEL SECURITY;

-- AI Cost Limits RLS: Authenticated users can read plan limits; Service role / Admins can modify
DO $$
BEGIN
    DROP POLICY IF EXISTS "Public can view ai cost limits" ON public.ai_cost_limits;
    CREATE POLICY "Public can view ai cost limits"
        ON public.ai_cost_limits
        FOR SELECT
        TO authenticated, anon
        USING (true);
END $$;

-- AI Spending Alerts RLS: Only admins / service role can view alerts
DO $$
BEGIN
    DROP POLICY IF EXISTS "Admins can view ai spending alerts" ON public.ai_spending_alerts;
    CREATE POLICY "Admins can view ai spending alerts"
        ON public.ai_spending_alerts
        FOR ALL
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
            )
        );
END $$;
