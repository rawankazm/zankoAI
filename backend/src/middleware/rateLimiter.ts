import { Request, Response, NextFunction } from 'express';
import { redis } from '../config/redis.js';
import { env } from '../config/env.js';
import { RateLimitError } from '../utils/apiError.js';
import { logger } from '../config/logger.js';

// Fallback in-memory map if Redis is not yet connected
const inMemoryStore = new Map<string, { count: number; resetTime: number }>();

export const rateLimiter = (
  windowMs = env.RATE_LIMIT_WINDOW_MS,
  maxRequests = env.RATE_LIMIT_MAX_REQUESTS
) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    // Unique identifier: user ID if authenticated, else client IP
    const identifier = req.user?.id || req.ip || req.socket.remoteAddress || 'anonymous';
    const key = `ratelimit:${identifier}`;

    try {
      // Attempt Redis rate limit
      const current = await redis.incr(key);
      if (current === 1) {
        await redis.pexpire(key, windowMs);
      }

      const ttl = await redis.pttl(key);
      res.setHeader('X-RateLimit-Limit', maxRequests.toString());
      res.setHeader('X-RateLimit-Remaining', Math.max(0, maxRequests - current).toString());
      res.setHeader('X-RateLimit-Reset', (Date.now() + ttl).toString());

      if (current > maxRequests) {
        throw new RateLimitError();
      }

      next();
    } catch (error) {
      if (error instanceof RateLimitError) {
        return next(error);
      }

      // Memory fallback if Redis operation failed
      const now = Date.now();
      const record = inMemoryStore.get(identifier);

      if (!record || now > record.resetTime) {
        inMemoryStore.set(identifier, { count: 1, resetTime: now + windowMs });
        return next();
      }

      record.count += 1;
      if (record.count > maxRequests) {
        return next(new RateLimitError());
      }

      next();
    }
  };
};
