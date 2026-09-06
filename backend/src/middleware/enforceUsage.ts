import { Request, Response, NextFunction } from 'express';
import { UsageService } from '../services/usage.service.js';
import { FeatureName, QuotaCheckResult } from '../types/usage.types.js';
import { UnauthorizedError } from '../utils/apiError.js';

// Extend Express Request interface to expose verified usage metrics to downstream controllers
declare global {
  namespace Express {
    interface Request {
      usageInfo?: QuotaCheckResult;
    }
  }
}

export interface EnforceUsageOptions {
  increment?: number;
  extractIdempotencyKey?: boolean;
}

/**
 * Server-authoritative usage quota enforcement middleware.
 * Enforces plan limits atomically before executing paid or rate-restricted AI operations.
 * "Never trust Flutter": all verification and increments occur server-side.
 */
export const enforceUsage = (feature: FeatureName, options: EnforceUsageOptions = {}) => {
  const increment = options.increment ?? 1;
  const useIdempotency = options.extractIdempotencyKey ?? true;

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user || !req.user.id) {
        throw new UnauthorizedError('Authentication required before verifying usage limits');
      }

      const userId = req.user.id;

      // Extract idempotency key from request headers to prevent double-counting on retries
      let idempotencyKey: string | undefined;
      if (useIdempotency) {
        const rawKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
        if (typeof rawKey === 'string' && rawKey.trim().length > 0) {
          idempotencyKey = rawKey.trim();
        }
      }

      // Execute authoritative atomic consumption
      const result = await UsageService.consumeQuota(userId, feature, increment, idempotencyKey);

      // Set standard RFC-compatible rate limiting headers
      res.setHeader('X-RateLimit-Limit', result.limit.toString());
      res.setHeader('X-RateLimit-Remaining', result.remaining.toString());
      res.setHeader('X-RateLimit-Reset', result.reset_at);

      if (!result.allowed) {
        const periodName = result.period_type === 'monthly' ? 'monthly' : 'daily';
        const isFree = result.plan === 'free';
        const userMsg = isFree
          ? `پلانی بێبەرامبەر (Free Plan) بۆ ${feature} تەواو بوو (${result.limit}/${result.limit}). تکایە ئەپکە بەرزبکەرەوە بۆ VIP/Premium.`
          : `Fair-use limit reached for ${feature} (${result.limit}/${result.limit}). Resets at ${result.reset_at}.`;

        res.status(429).json({
          success: false,
          error: {
            code: 'QUOTA_EXCEEDED',
            message: userMsg,
            feature: result.feature,
            plan: result.plan,
            current_usage: result.current_usage,
            limit: result.limit,
            remaining: 0,
            reset_at: result.reset_at,
            period_type: result.period_type,
          },
        });
        return;
      }

      // Attach authoritative quota result to request
      req.usageInfo = result;
      next();
    } catch (error) {
      next(error);
    }
  };
};
