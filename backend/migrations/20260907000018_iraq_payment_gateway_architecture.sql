-- ==============================================================================
-- ZankoAI Migration: Iraq Payment Gateway Abstraction & Transaction Architecture
-- Migration ID: 20260907000018_iraq_payment_gateway_architecture.sql
-- ==============================================================================

-- 1. CREATE PAYMENTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    order_id TEXT NOT NULL UNIQUE,
    transaction_id TEXT,
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL CHECK (currency IN ('IQD', 'USD', 'EUR')),
    status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'failed', 'cancelled', 'refunded')),
    plan TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance & Lookup Indexes
CREATE INDEX IF NOT EXISTS idx_payments_user_id 
    ON public.payments(user_id);

CREATE INDEX IF NOT EXISTS idx_payments_transaction_id 
    ON public.payments(transaction_id);

CREATE INDEX IF NOT EXISTS idx_payments_status_created 
    ON public.payments(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_provider 
    ON public.payments(provider);


-- 2. CREATE PAYMENT EVENTS TABLE (Idempotency & Audit Trail)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
    provider TEXT NOT NULL,
    provider_event_id TEXT,
    event_type TEXT NOT NULL,
    idempotency_key TEXT UNIQUE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast event retrieval and idempotency checks
CREATE INDEX IF NOT EXISTS idx_payment_events_payment_id 
    ON public.payment_events(payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_events_idempotency 
    ON public.payment_events(idempotency_key);

CREATE INDEX IF NOT EXISTS idx_payment_events_provider_event 
    ON public.payment_events(provider, provider_event_id);


-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- Zero client trust: authenticated users can only READ their own payments.
-- All writes (INSERT, UPDATE, DELETE) are reserved exclusively for service_role.
-- ------------------------------------------------------------------------------
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
CREATE POLICY "Users can view own payments"
    ON public.payments
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own payment events" ON public.payment_events;
CREATE POLICY "Users can view own payment events"
    ON public.payment_events
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.payments p
            WHERE p.id = payment_id AND p.user_id = auth.uid()
        )
    );
