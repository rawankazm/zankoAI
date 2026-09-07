-- ==============================================================================
-- ZankoAI Migration: Production-Ready Premium Subscription System
-- Migration ID: 20260907000016_premium_subscription_system.sql
-- ==============================================================================

-- 1. CREATE SUBSCRIPTIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (
        plan IN (
            'FREE',
            'PREMIUM_MONTHLY',
            'PREMIUM_YEARLY',
            'STUDENT',
            'UNIVERSITY',
            'TEAM'
        )
    ),
    status TEXT NOT NULL CHECK (
        status IN (
            'trialing',
            'active',
            'past_due',
            'canceled',
            'expired',
            'incomplete'
        )
    ),
    provider TEXT NOT NULL,
    provider_customer_id TEXT,
    provider_subscription_id TEXT,
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance & Query Indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id 
    ON public.subscriptions(user_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status 
    ON public.subscriptions(user_id, status);

CREATE INDEX IF NOT EXISTS idx_subscriptions_provider_sub_id 
    ON public.subscriptions(provider, provider_subscription_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_period_end 
    ON public.subscriptions(current_period_end);


-- 2. CREATE SUBSCRIPTION EVENTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    provider TEXT NOT NULL,
    provider_event_id TEXT,
    idempotency_key TEXT UNIQUE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance & Idempotency Indexes
CREATE INDEX IF NOT EXISTS idx_sub_events_user_created 
    ON public.subscription_events(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sub_events_subscription_id 
    ON public.subscription_events(subscription_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sub_events_provider_event 
    ON public.subscription_events(provider, provider_event_id)
    WHERE provider_event_id IS NOT NULL;


-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- Zero client trust: authenticated users can only READ their own subscriptions and events.
-- Modifications (INSERT, UPDATE, DELETE) are strictly reserved for service_role.
-- ------------------------------------------------------------------------------
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can view own subscriptions"
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
