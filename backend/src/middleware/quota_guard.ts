import { Request, Response, NextFunction } from 'express';
import { redis } from '../config/redis.js';

export const quotaGuard = (featureName: string = 'ai_chat') => {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Authentication required' });
    }

    const { id: userId, isVip } = req.user;
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const quotaKey = `quota:${featureName}:${userId}:${today}`;

    // Free users: 10 daily messages; VIP users: 500 daily messages
    const dailyLimit = isVip ? 500 : 10;

    try {
      const currentUsage = await redis.incr(quotaKey);
      if (currentUsage === 1) {
        await redis.expire(quotaKey, 86400); // 24 hours TTL
      }

      if (currentUsage > dailyLimit) {
        return res.status(403).json({
          success: false,
          error: isVip
            ? 'Daily VIP fair usage quota reached (500 requests). Resets at midnight.'
            : 'پلانی بێبەرامبەر (Free Plan) بۆ ئەمڕۆ تەواو بوو (١٠ پەیام). تکایە ئەپکە بەرزبکەرەوە بۆ VIP بۆ بەکارهێنانی بێسنوور.',
          code: 'QUOTA_EXCEEDED',
          isVip,
          currentUsage,
          dailyLimit,
        });
      }

      next();
    } catch (err) {
      // Allow request if Redis is down
      next();
    }
  };
};
