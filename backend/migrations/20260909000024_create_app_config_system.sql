-- ==============================================================================
-- ZankoAI Migration: App Config & Payment Settings System
-- Migration Version: 20260909000024_create_app_config_system.sql
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL DEFAULT '{}'::jsonb,
    fastpay_number TEXT,
    fib_number TEXT,
    zaincash_number TEXT,
    whatsapp_number TEXT,
    telegram_username TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Ensure all columns exist
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS value JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS fastpay_number TEXT;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS fib_number TEXT;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS zaincash_number TEXT;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS telegram_username TEXT;
ALTER TABLE public.config ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Enable RLS
ALTER TABLE public.config ENABLE ROW LEVEL SECURITY;

-- Allow public read access to config
DROP POLICY IF EXISTS "Public can view config" ON public.config;
CREATE POLICY "Public can view config"
    ON public.config
    FOR SELECT
    USING (true);

-- Allow admins and service_role to update/insert config
DROP POLICY IF EXISTS "Admins can update config" ON public.config;
CREATE POLICY "Admins can update config"
    ON public.config
    FOR ALL
    USING (
        auth.role() = 'service_role' OR 
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.is_admin = true
        )
    )
    WITH CHECK (
        auth.role() = 'service_role' OR 
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.is_admin = true
        )
    );

-- Seed initial payment_numbers
INSERT INTO public.config (key, value, fastpay_number, fib_number, zaincash_number, whatsapp_number, telegram_username, updated_at)
VALUES (
    'payment_numbers',
    jsonb_build_object(
        'fastpay', '07509987345',
        'fib', '07509987345',
        'zaincash', '07509987345',
        'whatsapp', '07509987345',
        'telegram', 'rawankurdi'
    ),
    '07509987345',
    '07509987345',
    '07509987345',
    '07509987345',
    'rawankurdi',
    timezone('utc'::text, now())
)
ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    fastpay_number = EXCLUDED.fastpay_number,
    fib_number = EXCLUDED.fib_number,
    zaincash_number = EXCLUDED.zaincash_number,
    whatsapp_number = EXCLUDED.whatsapp_number,
    telegram_username = EXCLUDED.telegram_username,
    updated_at = timezone('utc'::text, now());

-- Seed initial version_config if not present
INSERT INTO public.config (key, value, updated_at)
VALUES (
    'version_config',
    jsonb_build_object(
        'min_version', '1.0.0',
        'latest_version', '1.0.0',
        'is_force_update', false,
        'update_url', 'https://play.google.com/store/apps/details?id=com.zankoai.app'
    ),
    timezone('utc'::text, now())
)
ON CONFLICT (key) DO NOTHING;
