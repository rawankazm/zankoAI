import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';

// Supabase Admin Client bypassing RLS via Service Role Key (Used only on trusted backend)
export const supabaseAdmin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});
