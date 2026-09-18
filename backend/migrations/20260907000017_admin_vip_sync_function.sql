-- ==============================================================================
-- ZankoAI Migration: Admin VIP Sync Function & Security Bypass Handler
-- Migration ID: 20260907000017_admin_vip_sync_function.sql
-- ==============================================================================

-- 1. Update enforce_profile_update_security to respect transaction-level bypass
CREATE OR REPLACE FUNCTION public.enforce_profile_update_security()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS '
BEGIN
    -- Allow service_role, admin, or explicit system bypass to update all fields
    IF auth.uid() IS NULL 
       OR public.is_admin() 
       OR current_setting(''app.bypass_profile_security'', true) = ''true'' THEN
        RETURN NEW;
    END IF;

    -- Non-admin client checks:
    -- Rule 3: Users cannot change id, role, plan, status
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION ''Security violation: Profile ID cannot be modified.'';
    END IF;

    IF NEW.role IS DISTINCT FROM OLD.role THEN
        RAISE EXCEPTION ''Security violation: User role cannot be modified by the client.'';
    END IF;

    IF NEW.plan IS DISTINCT FROM OLD.plan THEN
        RAISE EXCEPTION ''Security violation: Subscription plan cannot be modified directly.'';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION ''Security violation: Account status cannot be modified by the user.'';
    END IF;

    -- Reset or prevent altering VIP status and scores directly from client
    IF NEW.is_vip IS DISTINCT FROM OLD.is_vip THEN
        NEW.is_vip := OLD.is_vip;
    END IF;

    IF NEW.vip_status IS DISTINCT FROM OLD.vip_status THEN
        NEW.vip_status := OLD.vip_status;
    END IF;

    IF NEW.vip_expiry IS DISTINCT FROM OLD.vip_expiry THEN
        NEW.vip_expiry := OLD.vip_expiry;
    END IF;

    RETURN NEW;
END;
';

-- 2. Create the SECURITY DEFINER function to activate verified VIP status
CREATE OR REPLACE FUNCTION public.sync_admin_approved_vip(
    p_user_id UUID,
    p_plan TEXT DEFAULT 'PREMIUM_MONTHLY',
    p_days INTEGER DEFAULT 365
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS '
DECLARE
    v_expiry TIMESTAMPTZ;
    v_sub_id UUID;
BEGIN
    -- Ensure caller is modifying their own account or is an admin
    IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION ''Permission denied: Cannot sync VIP for another user.'';
    END IF;

    v_expiry := NOW() + (p_days || '' days'')::INTERVAL;

    -- Set local transaction bypass flag so trigger permits the update
    PERFORM set_config(''app.bypass_profile_security'', ''true'', true);

    -- Update public.profiles
    UPDATE public.profiles
    SET 
        is_vip = true,
        vip_status = ''active'',
        plan = ''premium'',
        vip_expiry = v_expiry,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Update or insert public.subscriptions if table exists
    BEGIN
        INSERT INTO public.subscriptions (
            user_id,
            plan,
            status,
            provider,
            current_period_start,
            current_period_end,
            cancel_at_period_end,
            updated_at
        ) VALUES (
            p_user_id,
            CASE WHEN p_days >= 365 THEN ''PREMIUM_YEARLY'' ELSE ''PREMIUM_MONTHLY'' END,
            ''active'',
            ''admin'',
            NOW(),
            v_expiry,
            false,
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            plan = EXCLUDED.plan,
            status = ''active'',
            provider = ''admin'',
            current_period_start = NOW(),
            current_period_end = v_expiry,
            cancel_at_period_end = false,
            updated_at = NOW()
        RETURNING id INTO v_sub_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        ''success'', true,
        ''user_id'', p_user_id,
        ''is_vip'', true,
        ''vip_expiry'', v_expiry
    );
END;
';

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.sync_admin_approved_vip(UUID, TEXT, INTEGER) TO authenticated, anon, service_role;
