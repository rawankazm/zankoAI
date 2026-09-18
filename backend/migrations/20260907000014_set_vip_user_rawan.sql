-- ==============================================================================
-- ZankoAI Migration: Set VIP Status for User rawankurdi181@gmail.com
-- Migration ID: 20260907000014_set_vip_user_rawan.sql
-- ==============================================================================

-- 1. Update public.profiles
UPDATE public.profiles
SET 
    is_vip = true,
    vip_status = 'active',
    plan = 'premium',
    vip_expiry = NOW() + INTERVAL '100 years',
    updated_at = NOW()
WHERE LOWER(email) = 'rawankurdi181@gmail.com';

-- 2. Update auth.users metadata for JWT claims
UPDATE auth.users
SET 
    raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || '{"is_vip": true, "vip_status": "active", "plan": "premium"}'::jsonb,
    raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"is_vip": true, "vip_status": "active", "plan": "premium"}'::jsonb
WHERE LOWER(email) = 'rawankurdi181@gmail.com';
