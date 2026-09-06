import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { env } from './env.js';
import { logger } from './logger.js';

// Server-side privileged client with full access (Bypasses RLS where necessary for admin/worker operations)
export const supabaseAdmin: SupabaseClient = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);

// Client-scoped factory for user tokens
export const createScopedClient = (accessToken: string): SupabaseClient => {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
};

export const checkSupabaseHealth = async (): Promise<boolean> => {
  try {
    const { error } = await supabaseAdmin.from('profiles').select('id').limit(1);
    // If table doesn't exist yet or query succeeds, connection is alive
    if (error && error.code !== 'PGRST116' && error.code !== 'PGRST204') {
      logger.warn(' Supabase database health check returned error:', error.message);
      return false;
    }
    return true;
  } catch (err) {
    logger.warn(' Supabase connectivity check failed:', err);
    return false;
  }
};
