-- ==============================================================================
-- ZankoAI Migration: Flexible VIP Plan Durations (1 Month, 3 Months, 9 Months)
-- Migration ID: 20260908000019_vip_flexible_plan_durations.sql
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.sync_admin_approved_vip(
    p_user_id UUID,
    p_plan TEXT DEFAULT 'PREMIUM_MONTHLY',
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS '
DECLARE
    v_existing_expiry TIMESTAMPTZ;
    v_expiry TIMESTAMPTZ;
    v_sub_id UUID;
    v_sub_plan TEXT;
BEGIN
    -- Ensure caller is modifying their own account or is an admin
    IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION ''Permission denied: Cannot sync VIP for another user.'';
    END IF;

    -- If existing VIP expiry is in the future, extend it; otherwise start from NOW()
    SELECT vip_expiry INTO v_existing_expiry FROM public.profiles WHERE id = p_user_id;
    IF v_existing_expiry IS NOT NULL AND v_existing_expiry > NOW() THEN
        v_expiry := v_existing_expiry + (p_days || '' days'')::INTERVAL;
    ELSE
        v_expiry := NOW() + (p_days || '' days'')::INTERVAL;
    END IF;

    -- Set local transaction bypass flag so trigger permits the update
    PERFORM set_config(''app.bypass_profile_security'', ''true'', true);

    -- Update public.profiles with exact expiration date
    UPDATE public.profiles
    SET 
        is_vip = true,
        vip_status = ''active'',
        plan = ''premium'',
        vip_expiry = v_expiry,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Determine valid subscription plan enum
    IF p_plan IS NOT NULL AND p_plan IN (''FREE'', ''PREMIUM_MONTHLY'', ''PREMIUM_YEARLY'', ''STUDENT'', ''UNIVERSITY'', ''TEAM'') THEN
        v_sub_plan := p_plan;
    ELSIF p_days >= 250 THEN
        v_sub_plan := ''PREMIUM_YEARLY'';
    ELSE
        v_sub_plan := ''PREMIUM_MONTHLY'';
    END IF;

    -- Update or insert public.subscriptions
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
            v_sub_plan,
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
        ''vip_plan'', v_sub_plan,
        ''vip_days'', p_days,
        ''vip_expiry'', v_expiry
    );
END;
';

GRANT EXECUTE ON FUNCTION public.sync_admin_approved_vip(UUID, TEXT, INTEGER) TO authenticated, anon, service_role;
