// ==============================================================================
// ZankoAI Admin: Supabase Client for Authentication ONLY
// ==============================================================================
// STRICT ARCHITECTURE CONSTRAINT:
// - Browser Supabase client is used EXCLUSIVELY for authentication/session handling.
// - All privileged administrative operations MUST route through DigitalOcean backend.
// - NEVER expose service_role key to this file or the browser.
// ==============================================================================

import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../config/env';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
