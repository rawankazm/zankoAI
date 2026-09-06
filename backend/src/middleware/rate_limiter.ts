import { Request, Response, NextFunction } from 'express';
import { redis } from '../config/redis.js';

interface RateLimitOptions {
  windowMs: number;
  maxRequests: number;
  keyPrefix?: string;
}

export const rateLimiter = (options: RateLimitOptions) => {
  const { windowMs, maxRequests, keyPrefix = 'rl' } = options;

  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const identifier = req.user?.id || req.ip || 'anonymous';
      const key = `${keyPrefix}:${identifier}`;
      const now = Date.now();
      const clearBefore = now - windowMs;

      // Sliding window using Redis sorted sets (ZSET)
      const pipeline = redis.pipeline();
      pipeline.zremrangebyscore(key, 0, clearBefore);
      pipeline.zadd(key, now, `${now}-${Math.random()}`);
      pipeline.zcard(key);
      pipeline.expire(key, Math.ceil(windowMs / 1000));

      const results = await pipeline.exec();
      const requestCount = (results?.[2]?.[1] as number) || 0;

      if (requestCount > maxRequests) {
        return res.status(429).json({
          success: false,
          error: 'Too many requests. Please slow down and try again later.',
        });
      }

      next();
    } catch (err) {
      // Fail open if Redis is temporarily unreachable
      next();
    }
  };
};
