// ==============================================================================
// ZankoAI Admin Dashboard: Client Environment Configuration
// ==============================================================================
// SECURITY [PROMPT 36]:
// - Strictly zero private secrets (service_role, AI keys, payment keys) here.
// - Only public configuration needed to authenticate via Supabase and talk to backend.
// ==============================================================================

export const API_URL = import.meta.env.VITE_API_URL || 'https://api.zankoai.com';
export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://kjslmvoaanoqrizawllh.supabase.co';
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_';
