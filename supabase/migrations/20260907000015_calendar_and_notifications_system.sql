-- ==============================================================================
-- ZankoAI Migration: Comprehensive Calendar and Notification System
-- Migration ID: 20260907000015_calendar_and_notifications_system.sql
-- ==============================================================================

-- 1. CALENDAR EVENTS ENHANCEMENTS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.calendar_events
    ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS notification_lead_minutes INTEGER DEFAULT 30 CHECK (notification_lead_minutes >= 0),
    ADD COLUMN IF NOT EXISTS recurrence_rule TEXT,
    ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT false;

-- Update or relax event_type check constraint for all required types
ALTER TABLE public.calendar_events 
    DROP CONSTRAINT IF EXISTS calendar_events_event_type_check,
    DROP CONSTRAINT IF EXISTS chk_calendar_events_type;

ALTER TABLE public.calendar_events
    ADD CONSTRAINT chk_calendar_events_type CHECK (
        event_type IN (
            'class',
            'exam',
            'assignment_deadline',
            'reminder',
            'university_event',
            'personal_study_event',
            'lecture',
            'assignment',
            'personal'
        )
    );

CREATE INDEX IF NOT EXISTS idx_calendar_events_user_time 
    ON public.calendar_events(user_id, start_time, end_time);

CREATE INDEX IF NOT EXISTS idx_calendar_events_type_start 
    ON public.calendar_events(event_type, start_time);


-- 2. NOTIFICATIONS ENHANCEMENTS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.notifications
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS reference_id UUID,
    ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'delivered';

-- Unique idempotency key to strictly prevent duplicate notifications
ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS uq_notifications_idempotency;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key 
    ON public.notifications(idempotency_key) 
    WHERE idempotency_key IS NOT NULL;

-- Update notification type check constraint
ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check,
    DROP CONSTRAINT IF EXISTS chk_notifications_type;

ALTER TABLE public.notifications
    ADD CONSTRAINT chk_notifications_type CHECK (
        type IN (
            'assignment_reminder',
            'exam_reminder',
            'teacher_announcement',
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

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
    ON public.notifications(user_id, is_read, created_at DESC);


-- 3. NOTIFICATION PREFERENCES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    assignment_reminders BOOLEAN NOT NULL DEFAULT true,
    exam_reminders BOOLEAN NOT NULL DEFAULT true,
    teacher_announcements BOOLEAN NOT NULL DEFAULT true,
    system_notifications BOOLEAN NOT NULL DEFAULT true,
    subscription_notifications BOOLEAN NOT NULL DEFAULT true,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    lead_time_minutes INTEGER NOT NULL DEFAULT 60 CHECK (lead_time_minutes >= 0),
    timezone TEXT NOT NULL DEFAULT 'Asia/Baghdad',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_preferences_owner_all" ON public.notification_preferences;
CREATE POLICY "notification_preferences_owner_all" ON public.notification_preferences
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- 4. NOTIFICATION DEVICES ENHANCEMENTS
-- ------------------------------------------------------------------------------
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
