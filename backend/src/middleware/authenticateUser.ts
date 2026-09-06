import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { redis } from '../config/redis.js';
import { UnauthorizedError, ForbiddenError } from '../utils/apiError.js';
import { UserProfile } from '../types/user.types.js';
import { SecurityLogger } from '../utils/securityLogger.js';
import { logger } from '../config/logger.js';
import { ActivityTrackerService } from '../services/activity_tracker.service.js';

export const authenticateUser = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      SecurityLogger.fromRequest(req, 'AUTH_FAILURE', 'WARN', 'DENIED', {
        reason: 'Missing or malformed Authorization header',
      });
      throw new UnauthorizedError('Missing or malformed Authorization header. Use Bearer <token>');
    }

    const token = authHeader.split(' ')[1]?.trim();
    if (!token) {
      SecurityLogger.fromRequest(req, 'AUTH_FAILURE', 'WARN', 'DENIED', {
        reason: 'Empty Bearer token',
      });
      throw new UnauthorizedError('Bearer token is empty');
    }

    // Basic structure sanity check (JWT format: header.payload.signature)
    const tokenParts = token.split('.');
    if (tokenParts.length !== 3 || token.length < 20 || token.length > 4096) {
      SecurityLogger.fromRequest(req, 'TOKEN_INVALID', 'WARN', 'BLOCKED', {
        reason: 'Token structure malformed',
      });
      throw new UnauthorizedError('Malformed authentication token structure');
    }

    // Token revocation check in Redis (Denylist)
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    try {
      const isRevoked = await redis.get(`revoked:token:${tokenHash}`);
      if (isRevoked) {
        SecurityLogger.fromRequest(req, 'TOKEN_REVOKED', 'WARN', 'BLOCKED', {
          tokenHash: tokenHash.substring(0, 10),
        });
        throw new UnauthorizedError('Authentication token has been revoked or invalidated');
      }
    } catch (redisErr: any) {
      if (redisErr instanceof UnauthorizedError) throw redisErr;
      // If Redis connection fails, proceed with Supabase Auth validation
    }

    // Authoritative Token Verification with Supabase Auth engine
    const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !authData.user) {
      SecurityLogger.fromRequest(req, 'AUTH_FAILURE', 'WARN', 'DENIED', {
        reason: authError?.message || 'User not found in Supabase Auth',
      });
      throw new UnauthorizedError('Invalid or expired authentication token');
    }

    const user = authData.user;

    // Fetch authoritative user profile directly from PostgreSQL public.profiles
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      logger.error(`Failed to fetch user profile for ${user.id}: ${profileError.message}`);
    }

    let profile: UserProfile;

    if (profileData) {
      profile = profileData as UserProfile;
    } else {
      // Safe fallback profile if record was not backfilled yet
      profile = {
        id: user.id,
        email: user.email || '',
        full_name:
          user.user_metadata?.full_name ||
          user.user_metadata?.name ||
          user.email?.split('@')[0] ||
          'Student',
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

    // Account Status Guard: Banned or Suspended accounts are immediately blocked
    if (profile.status === 'banned' || profile.status === 'suspended') {
      SecurityLogger.fromRequest(req, 'ACCOUNT_SUSPENDED', 'WARN', 'DENIED', {
        userId: user.id,
        accountStatus: profile.status,
      });
      throw new ForbiddenError(
        `Account access denied. Your account status is '${profile.status}'. Please contact administration.`
      );
    }

    // Server-side Subscription & VIP validation: Verify expiration against server clock
    if (profile.vip_status === 'active' || profile.is_vip) {
      if (profile.vip_expires_at) {
        const expiry = new Date(profile.vip_expires_at);
        if (expiry < new Date()) {
          // Subscription has expired - downgrade status in memory and async sync to DB
          profile.is_vip = false;
          profile.vip_status = 'expired';
          profile.plan = 'free';

          supabaseAdmin
            .from('profiles')
            .update({ is_vip: false, vip_status: 'expired', plan: 'free', updated_at: new Date().toISOString() })
            .eq('id', user.id)
            .then(() => logger.info(`Auto-downgraded expired VIP for user: ${user.id}`))
            .catch((err) => logger.warn(`Failed to auto-downgrade VIP in DB: ${err.message}`));
        }
      }
    }

    // Attach verified server-side identity to Express Request
    req.user = {
      id: user.id,
      email: user.email,
      app_metadata: user.app_metadata,
      user_metadata: user.user_metadata,
    };
    req.profile = profile;
    req.token = token;

    // Track active presence asynchronously (Deduplicated via Redis, max 1 write/user/day)
    ActivityTrackerService.trackUser(user.id, profile.role, profile.plan);

    next();
  } catch (error) {
    next(error);
  }
};

// Backwards compatibility alias
export const authenticate = authenticateUser;
