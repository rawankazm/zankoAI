import { Request, Response, NextFunction } from 'express';
import { redis } from '../config/redis.js';
import { env } from '../config/env.js';
import { RateLimitError } from '../utils/apiError.js';
import { SecurityLogger } from '../utils/securityLogger.js';
import { logger } from '../config/logger.js';

// Fallback in-memory map if Redis is not reachable
const inMemoryStore = new Map<string, { count: number; resetTime: number }>();

export interface RateLimiterOptions {
  windowMs?: number;
  maxRequests?: number;
  keyPrefix?: string;
  skipFailedRequests?: boolean;
}

/**
 * General Sliding Window Rate Limiter
 */
export const rateLimiter = (options?: RateLimiterOptions | number, maxReqs?: number) => {
  let windowMs = env.RATE_LIMIT_WINDOW_MS;
  let maxRequests = env.RATE_LIMIT_MAX_REQUESTS;
  let keyPrefix = 'ratelimit:global';

  if (typeof options === 'number') {
    windowMs = options;
    if (maxReqs) maxRequests = maxReqs;
  } else if (options) {
    if (options.windowMs) windowMs = options.windowMs;
    if (options.maxRequests) maxRequests = options.maxRequests;
    if (options.keyPrefix) keyPrefix = options.keyPrefix;
  }

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    // Unique identifier: user ID if authenticated, else client IP.
    // SECURITY [H-04]: Use req.ip (resolved by Express trust proxy), NOT raw X-Forwarded-For header.
    // Manually reading X-Forwarded-For allows attackers to spoof their IP and bypass rate limiting.
    const clientIp = req.ip || req.socket.remoteAddress || 'anonymous';
    const identifier = req.user?.id ? `user:${req.user.id}` : `ip:${clientIp}`;
    const key = `${keyPrefix}:${identifier}`;

    try {
      const current = await redis.incr(key);
      if (current === 1) {
        await redis.pexpire(key, windowMs);
      }

      const ttl = await redis.pttl(key);
      const remaining = Math.max(0, maxRequests - current);
      const resetTime = Date.now() + Math.max(0, ttl);

      res.setHeader('X-RateLimit-Limit', maxRequests.toString());
      res.setHeader('X-RateLimit-Remaining', remaining.toString());
      res.setHeader('X-RateLimit-Reset', resetTime.toString());

      if (current > maxRequests) {
        res.setHeader('Retry-After', Math.ceil(Math.max(1, ttl) / 1000).toString());

        SecurityLogger.fromRequest(req, 'RATE_LIMIT_EXCEEDED', 'WARN', 'BLOCKED', {
          keyPrefix,
          maxRequests,
          currentRequests: current,
        });

        throw new RateLimitError();
      }

      next();
    } catch (error) {
      if (error instanceof RateLimitError) {
        return next(error);
      }

      // In-Memory Fallback if Redis is unavailable
      const now = Date.now();
      const record = inMemoryStore.get(key);

      if (!record || now > record.resetTime) {
        inMemoryStore.set(key, { count: 1, resetTime: now + windowMs });
        return next();
      }

      record.count += 1;
      const remaining = Math.max(0, maxRequests - record.count);
      res.setHeader('X-RateLimit-Limit', maxRequests.toString());
      res.setHeader('X-RateLimit-Remaining', remaining.toString());
      res.setHeader('X-RateLimit-Reset', record.resetTime.toString());

      if (record.count > maxRequests) {
        res.setHeader('Retry-After', Math.ceil((record.resetTime - now) / 1000).toString());
        return next(new RateLimitError());
      }

      next();
    }
  };
};

/**
 * Dedicated Brute-Force Protection Limiter for Authentication and Sensitive Actions
 */
export const bruteForceLimiter = (options: {
  windowMs?: number;
  maxAttempts?: number;
  keyPrefix?: string;
} = {}) => {
  const windowMs = options.windowMs || 15 * 60 * 1000; // 15 minutes default
  const maxAttempts = options.maxAttempts || 5;       // 5 attempts default
  const keyPrefix = options.keyPrefix || 'bruteforce:auth';

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    // SECURITY [H-04]: Use req.ip (resolved by Express trust proxy), NOT raw X-Forwarded-For.
    const clientIp = req.ip || req.socket.remoteAddress || 'anonymous';

    // Account specific identifier if email / identifier provided in body
    const targetAccount = typeof req.body?.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : 'global';

    const key = `${keyPrefix}:${clientIp}:${targetAccount}`;

    try {
      const attempts = await redis.incr(key);
      if (attempts === 1) {
        await redis.pexpire(key, windowMs);
      }

      const ttl = await redis.pttl(key);

      if (attempts > maxAttempts) {
        const retrySeconds = Math.ceil(Math.max(1, ttl) / 1000);
        res.setHeader('Retry-After', retrySeconds.toString());

        SecurityLogger.fromRequest(req, 'BRUTE_FORCE_BLOCKED', 'CRITICAL', 'BLOCKED', {
          targetAccount,
          clientIp,
          attempts,
          lockoutSeconds: retrySeconds,
        });

        return next(
          new RateLimitError(
            `Too many failed attempts. Account or IP temporarily locked. Please try again in ${retrySeconds} seconds.`
          )
        );
      }

      next();
    } catch (err: any) {
      if (err instanceof RateLimitError) return next(err);
      // SECURITY [H-05]: Fail CLOSED on Redis failure for brute-force limiter.
      // Silently allowing requests through when Redis is down enables brute-force attacks.
      logger.error('[BruteForceLimiter] Redis unavailable — failing closed to prevent brute-force attacks:', err.message);
      res.status(503).json({
        success: false,
        error: {
          code: 'SERVICE_UNAVAILABLE',
          message: 'Authentication service temporarily unavailable. Please try again shortly.',
        },
      });
    }
  };
};

// Backwards compatibility alias
export default rateLimiter;
