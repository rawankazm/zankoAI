-- ==============================================================================
-- ZankoAI Migration: Secure Admin Management System & Immutable Audit Engine
-- Migration Version: 20260908000022_admin_system_and_audit_logs.sql
-- ==============================================================================

-- 1. Ensure public.audit_logs table exists and is fully structured
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

-- Ensure all required columns exist in audit_logs
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS resource_type TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS resource_id TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS ip_address TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS changes JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

COMMENT ON TABLE public.audit_logs IS 'System-wide immutable security audit log tracking all administrative and sensitive operations.';

-- 2. Ensure schema compatibility for payments table (add provider and plan columns if missing)
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'fib';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS order_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS transaction_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'premium';

-- Safely sync legacy 'gateway' to 'provider' if gateway exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payments' AND column_name = 'gateway'
    ) THEN
        EXECUTE 'UPDATE public.payments SET provider = gateway WHERE provider IS NULL OR provider = ''fib''';
    END IF;
END $$;

-- 3. Ensure schema compatibility for subscriptions table (add provider and plan columns if missing)
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'fib';
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'PREMIUM_MONTHLY';
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS current_period_start TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN DEFAULT false;

-- Safely sync legacy 'plan_name' to 'plan' if plan_name exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'plan_name'
    ) THEN
        EXECUTE 'UPDATE public.subscriptions SET plan = plan_name WHERE plan IS NULL OR plan = ''PREMIUM_MONTHLY''';
    END IF;
END $$;

-- 4. Ensure profiles columns exist for admin filtering
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'student';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'free';

-- 5. Performance Indexes for Admin Filtering & Pagination
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_desc 
    ON public.audit_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created 
    ON public.audit_logs (action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created 
    ON public.audit_logs (actor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_resource 
    ON public.audit_logs (resource_type, resource_id, created_at DESC);

-- Profiles filtering indexes
CREATE INDEX IF NOT EXISTS idx_profiles_status_role_plan 
    ON public.profiles (status, role, plan);

CREATE INDEX IF NOT EXISTS idx_profiles_created_at_desc 
    ON public.profiles (created_at DESC);

-- Subscriptions filtering indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_status_plan_date 
    ON public.subscriptions (status, plan, created_at DESC);

-- Payments filtering indexes
CREATE INDEX IF NOT EXISTS idx_payments_status_provider_date 
    ON public.payments (status, provider, created_at DESC);

-- 6. Row Level Security for Audit Logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "audit_logs_admin_select" ON public.audit_logs;
    CREATE POLICY "audit_logs_admin_select"
        ON public.audit_logs
        FOR SELECT
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
            )
        );

    DROP POLICY IF EXISTS "audit_logs_admin_insert" ON public.audit_logs;
    CREATE POLICY "audit_logs_admin_insert"
        ON public.audit_logs
        FOR INSERT
        TO authenticated, service_role
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
            )
            OR auth.role() = 'service_role'
        );

    -- Strict protection: Prevent UPDATE or DELETE on audit logs to guarantee immutability
    DROP POLICY IF EXISTS "audit_logs_no_update" ON public.audit_logs;
    DROP POLICY IF EXISTS "audit_logs_no_delete" ON public.audit_logs;
END $$;
