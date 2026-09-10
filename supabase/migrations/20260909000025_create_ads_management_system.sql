-- ==============================================================================
-- ZankoAI Migration: Production Ads Management System
-- Migration Version: 20260909000025_create_ads_management_system.sql
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.ads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    "titleAr" TEXT DEFAULT '',
    "titleEn" TEXT DEFAULT '',
    description TEXT DEFAULT '',
    "descAr" TEXT DEFAULT '',
    "descEn" TEXT DEFAULT '',
    "buttonTextKu" TEXT DEFAULT 'سەردان بکە',
    "buttonTextAr" TEXT DEFAULT 'تفاصيل',
    "buttonTextEn" TEXT DEFAULT 'View',
    "imageUrl" TEXT DEFAULT '',
    "linkUrl" TEXT DEFAULT '',
    "isActive" BOOLEAN DEFAULT true,
    "showOnScreens" JSONB DEFAULT '["home"]'::jsonb,
    click_count INTEGER DEFAULT 0,
    impression_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ads_is_active ON public.ads ("isActive");
CREATE INDEX IF NOT EXISTS idx_ads_created_at ON public.ads (created_at DESC);

-- Enable RLS
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- 1. Public can view active ads
DROP POLICY IF EXISTS "Public can view active ads" ON public.ads;
CREATE POLICY "Public can view active ads"
    ON public.ads
    FOR SELECT
    TO public
    USING ("isActive" = true);

-- 2. Admins and Service Role have full management access
DROP POLICY IF EXISTS "Admins have full access to ads" ON public.ads;
CREATE POLICY "Admins have full access to ads"
    ON public.ads
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

GRANT ALL ON public.ads TO service_role;
GRANT SELECT ON public.ads TO anon, authenticated;
