-- ==============================================================================
-- ZankoAI Production Push Notification Architecture Migration
-- Migration: 20260908000023_production_notification_architecture.sql
-- ==============================================================================

-- 1. ENSURE IS_ADMIN HELPER FUNCTION EXISTS AT THE VERY START
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT COALESCE((SELECT role = 'admin' FROM public.profiles WHERE id = auth.uid()), false);
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role, anon;

-- 2. UPDATE NOTIFICATIONS TYPE CHECK CONSTRAINT
-- Supports all 8 production categories + legacy types
ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check,
    DROP CONSTRAINT IF EXISTS chk_notifications_type;

ALTER TABLE public.notifications
    ADD CONSTRAINT chk_notifications_type CHECK (
        type IN (
            'assignment_reminder',
            'exam_reminder',
            'announcement',
            'teacher_announcement',
            'ai_job_completion',
            'subscription_activated',
            'subscription_expiring',
            'payment_result',
            'system_notification',
            'subscription_notification',
            'system',
            'broadcast',
            'vip',
            'academic',
            'reminder',
            'security'
        )
    );

-- 3. ENSURE COMPREHENSIVE NOTIFICATION FIELDS & NULLABLE USER_ID FOR BROADCASTS
-- Allow user_id to be NULL for broadcast/global notifications sent to all users
ALTER TABLE public.notifications
    ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS reference_id TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'delivered';

-- Index for user unread / read filtering
CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
    ON public.notifications(user_id, is_read, created_at DESC);

-- Unique idempotency index for duplicate prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key 
    ON public.notifications(idempotency_key) 
    WHERE idempotency_key IS NOT NULL;

-- Enable RLS and support Broadcast/Global notifications visibility
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications
    FOR SELECT TO authenticated, anon
    USING (
        user_id = auth.uid() 
        OR user_id IS NULL 
        OR type IN ('broadcast', 'system', 'announcement', 'teacher_announcement') 
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications
    FOR INSERT TO authenticated, anon
    WITH CHECK (
        user_id = auth.uid() 
        OR user_id IS NULL 
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications
    FOR UPDATE TO authenticated, anon
    USING (
        user_id = auth.uid() 
        OR user_id IS NULL 
        OR public.is_admin()
    )
    WITH CHECK (
        user_id = auth.uid() 
        OR user_id IS NULL 
        OR public.is_admin()
    );

-- Enable Supabase Realtime replication on public.notifications
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;
END $$;


-- 3. EXPAND NOTIFICATION PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    assignment_reminders BOOLEAN NOT NULL DEFAULT true,
    exam_reminders BOOLEAN NOT NULL DEFAULT true,
    teacher_announcements BOOLEAN NOT NULL DEFAULT true,
    announcements BOOLEAN NOT NULL DEFAULT true,
    ai_job_completion BOOLEAN NOT NULL DEFAULT true,
    subscription_notifications BOOLEAN NOT NULL DEFAULT true,
    payment_updates BOOLEAN NOT NULL DEFAULT true,
    system_notifications BOOLEAN NOT NULL DEFAULT true,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    lead_time_minutes INTEGER NOT NULL DEFAULT 60 CHECK (lead_time_minutes >= 0),
    timezone TEXT NOT NULL DEFAULT 'Asia/Baghdad',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Add any new preference columns if table already existed
ALTER TABLE public.notification_preferences
    ADD COLUMN IF NOT EXISTS announcements BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS ai_job_completion BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS payment_updates BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_preferences_owner_all" ON public.notification_preferences;
CREATE POLICY "notification_preferences_owner_all" ON public.notification_preferences
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- 4. MULTI-DEVICE REGISTRATION TABLE
CREATE TABLE IF NOT EXISTS public.notification_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_id TEXT,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    app_version TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_notification_devices_token UNIQUE (fcm_token)
);

ALTER TABLE public.notification_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_devices_owner_all" ON public.notification_devices;
CREATE POLICY "notification_devices_owner_all" ON public.notification_devices
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_notification_devices_user_active 
    ON public.notification_devices(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_notification_devices_token
    ON public.notification_devices(fcm_token);

CREATE INDEX IF NOT EXISTS idx_notification_devices_user_device
    ON public.notification_devices(user_id, device_id);

COMMENT ON TABLE public.notifications IS 'ZankoAI Production Notifications storing user_id, type, title, body, data, read_at, created_at';
COMMENT ON TABLE public.notification_devices IS 'Multi-device registration storing tokens, platforms, active statuses, and last seen timestamps';
COMMENT ON TABLE public.notification_preferences IS 'Granular user notification preferences per category with master push toggle';
