import { Request, Response, NextFunction } from 'express';
import { redis } from '../config/redis.js';
import { QuotaExceededError, UnauthorizedError } from '../utils/apiError.js';
import { logger } from '../config/logger.js';

// Default daily limits
const TIER_LIMITS = {
  admin: 10000,
  vip: 500,
  teacher: 300,
  student_free: 25,
};

export const checkUsage = (cost = 1) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.profile) {
        return next(new UnauthorizedError('User must be authenticated before checking usage'));
      }

      const user = req.profile;

      // Admins bypass usage quotas
      if (user.role === 'admin') {
        return next();
      }

      // Determine daily limit
      let maxLimit = TIER_LIMITS.student_free;
      if (user.is_vip || user.vip_status === 'active' || user.plan === 'premium') {
        maxLimit = TIER_LIMITS.vip;
      } else if (user.role === 'teacher') {
        maxLimit = TIER_LIMITS.teacher;
      }

      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const usageKey = `usage:daily:${user.id}:${today}`;

      let currentUsage = 0;

      try {
        currentUsage = await redis.incrby(usageKey, cost);

        // If newly created key, set TTL until end of current day (86400 seconds)
        if (currentUsage === cost) {
          await redis.expire(usageKey, 86400);
        }
      } catch (redisErr) {
        // If Redis is unreachable, fail-open gracefully with warning to maintain service availability
        logger.warn('Redis unavailable during checkUsage. Proceeding with caution:', redisErr);
        return next();
      }

      const remaining = Math.max(0, maxLimit - currentUsage);

      res.setHeader('X-Usage-Limit', maxLimit.toString());
      res.setHeader('X-Usage-Remaining', remaining.toString());

      if (currentUsage > maxLimit) {
        throw new QuotaExceededError(
          `Daily usage quota of ${maxLimit} requests exceeded. You have used ${currentUsage} requests today. Please upgrade to VIP or wait until tomorrow.`
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};
