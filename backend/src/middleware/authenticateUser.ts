import { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { UnauthorizedError } from '../utils/apiError.js';
import { UserProfile } from '../types/user.types.js';

export const authenticateUser = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or malformed Authorization header. Use Bearer <token>');
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      throw new UnauthorizedError('Bearer token is empty');
    }

    // Verify token with Supabase Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !authData.user) {
      throw new UnauthorizedError('Invalid or expired authentication token');
    }

    const user = authData.user;

    // Fetch corresponding profile from public.profiles
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    let profile: UserProfile;

    if (profileData) {
      profile = profileData as UserProfile;
    } else {
      // Fallback safe student profile if record was not backfilled yet
      profile = {
        id: user.id,
        email: user.email || '',
        full_name: (user.user_metadata?.full_name || user.user_metadata?.name || user.email?.split('@')[0] || 'Student'),
        role: 'student',
        status: 'active',
        plan: 'free',
        is_vip: false,
        vip_status: 'none',
        score: 0,
        rank_title: 'Newbie',
        created_at: user.created_at,
        updated_at: user.updated_at || user.created_at,
      };
    }

    // Attach to Express Request
    req.user = {
      id: user.id,
      email: user.email,
      app_metadata: user.app_metadata,
      user_metadata: user.user_metadata,
    };
    req.profile = profile;
    req.token = token;

    next();
  } catch (error) {
    next(error);
  }
};
