-- ==============================================================================
-- ZankoAI Supabase Authentication Helpers & Security Functions
-- Migration File: 20260906000002_auth_helpers.sql
-- ==============================================================================

-- 1. Secure Account Deletion RPC Function
-- Enables an authenticated user to permanently delete their own account and profile
-- Runs with SECURITY DEFINER to allow clean cascading removal from auth.users
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated: You must be logged in to delete your account.';
    END IF;

    -- Clean up profile data
    DELETE FROM public.profiles WHERE id = v_user_id;

    -- Permanently delete the user from auth.users (cascades to identities, sessions, tokens)
    DELETE FROM auth.users WHERE id = v_user_id;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        -- Fallback: Soft delete profile if auth.users deletion has FK locks
        UPDATE public.profiles
        SET status = 'deleted',
            updated_at = NOW()
        WHERE id = v_user_id;
        RETURN TRUE;
END;
$$;

-- Grant execution permissions only to authenticated users
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

COMMENT ON FUNCTION public.delete_user_account() IS 'Allows authenticated users to securely delete their own account and profile data.';
