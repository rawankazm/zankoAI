-- ==============================================================================
-- ZankoAI Migration: Premium Lifecycle, Grace Period & Payments Architecture
-- Migration ID: 20260908000020_premium_lifecycle_and_grace_period.sql
-- ==============================================================================

-- 1. ENSURE SUBSCRIPTIONS TABLE EXISTS WITH ALL REQUIRED COLUMNS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL DEFAULT 'FREE',
    status TEXT NOT NULL DEFAULT 'active',
    provider TEXT NOT NULL DEFAULT 'sandbox',
    provider_customer_id TEXT,
    provider_subscription_id TEXT,
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    grace_period_end TIMESTAMPTZ,
    auto_renew BOOLEAN NOT NULL DEFAULT false,
    renewal_reminder_sent_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- In case subscriptions table was previously created with partial columns:
ALTER TABLE public.subscriptions 
    ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'FREE',
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'sandbox',
    ADD COLUMN IF NOT EXISTS provider_customer_id TEXT,
    ADD COLUMN IF NOT EXISTS provider_subscription_id TEXT,
    ADD COLUMN IF NOT EXISTS current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS grace_period_end TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS renewal_reminder_sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 2. CREATE PERFORMANCE INDEXES FOR SUBSCRIPTIONS & MAINTENANCE WORKER
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id 
    ON public.subscriptions(user_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_lifecycle 
    ON public.subscriptions(status, current_period_end);

CREATE INDEX IF NOT EXISTS idx_subscriptions_grace 
    ON public.subscriptions(status, grace_period_end);

CREATE INDEX IF NOT EXISTS idx_subscriptions_reminders 
    ON public.subscriptions(status, current_period_end, renewal_reminder_sent_at);

-- 3. ENSURE SUBSCRIPTION EVENTS TABLE EXISTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'sandbox',
    provider_event_id TEXT,
    idempotency_key TEXT UNIQUE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sub_events_user_created 
    ON public.subscription_events(user_id, created_at DESC);

-- 4. ENSURE PAYMENTS TABLE EXISTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'sandbox',
    order_id TEXT NOT NULL UNIQUE,
    transaction_id TEXT,
    amount NUMERIC NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'IQD',
    status TEXT NOT NULL DEFAULT 'pending',
    plan TEXT NOT NULL DEFAULT 'PREMIUM_MONTHLY',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id 
    ON public.payments(user_id);

-- 5. ENABLE ROW LEVEL SECURITY & POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own subscription history" ON public.subscriptions;
CREATE POLICY "Users can view own subscription history"
    ON public.subscriptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own subscription events" ON public.subscription_events;
CREATE POLICY "Users can view own subscription events"
    ON public.subscription_events
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own payment history" ON public.payments;
CREATE POLICY "Users can view own payment history"
    ON public.payments
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
