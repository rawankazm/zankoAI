import { Request, Response, NextFunction } from 'express';
import { AiCostGuardService } from '../services/ai_cost_guard.service.js';
import { AiPlanTier } from '../types/ai_cost.types.js';
import { redis } from '../config/redis.js';
import { AppError, UnauthorizedError } from '../utils/apiError.js';
import { logger } from '../config/logger.js';

// Extend Express Request interface to expose aiCostInfo
declare global {
  namespace Express {
    interface Request {
      aiPlan?: AiPlanTier;
      aiBudgetStatus?: any;
    }
  }
}

/**
 * AI Cost Guard Middleware:
 * 1. Determines tier (Free vs Premium/VIP)
 * 2. Enforces tiered sliding window rate limiting
 * 3. Enforces maximum request payload character size
 * 4. Enforces concurrent in-flight job locks per user
 * 5. Pre-evaluates daily and monthly cost budgets
 * 6. Emits budget status headers
 */
export const aiCostGuard = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      throw new UnauthorizedError('User must be authenticated to invoke AI operations');
    }

    // 1. Determine Tier: Check plan, is_vip, or vip_status
    const profile = req.profile;
    const isPremium =
      profile?.plan === 'premium' ||
      profile?.is_vip === true ||
      profile?.vip_status === 'active' ||
      profile?.role === 'admin';

    const plan: AiPlanTier = isPremium ? 'premium' : 'free';
    req.aiPlan = plan;

    const limits = await AiCostGuardService.getLimits(plan);

    // 2. Sliding Window Rate Limiting (per minute per user)
    const currentMinute = Math.floor(Date.now() / 60000);
    const rateLimitKey = `ai:ratelimit:${userId}:${currentMinute}`;
    try {
      const requestsThisMinute = await redis.incr(rateLimitKey);
      if (requestsThisMinute === 1) {
        await redis.expire(rateLimitKey, 70); // Expire after slightly over a minute
      }

      if (requestsThisMinute > limits.rate_limit_per_min) {
        throw new AppError(
          `AI rate limit exceeded (${limits.rate_limit_per_min} requests/min for ${plan.toUpperCase()} tier). Please wait before sending more requests.`,
          429,
          'AI_RATE_LIMIT_EXCEEDED',
          true,
          {
            plan,
            limitPerMin: limits.rate_limit_per_min,
            retryAfterSeconds: 60 - (Math.floor(Date.now() / 1000) % 60),
          }
        );
      }
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      logger.warn('[aiCostGuard] Redis rate limit check skipped due to error', { error: err.message });
    }

    // 3. Request Payload Size Validation
    const textPayload =
      req.body?.message ||
      req.body?.prompt ||
      req.body?.text ||
      req.body?.content ||
      (typeof req.body === 'string' ? req.body : JSON.stringify(req.body || ''));

    const textLength = typeof textPayload === 'string' ? textPayload.length : 0;
    await AiCostGuardService.validateRequestSize(textLength, plan);

    // 4. Budget Checks (Daily and Monthly Hard Cutoff)
    const budgetStatus = await AiCostGuardService.checkBudgets(userId, plan);
    req.aiBudgetStatus = budgetStatus;

    // 5. Concurrency Control (Atomic acquire)
    await AiCostGuardService.acquireConcurrencySlot(userId, plan);

    // Ensure slot is reliably released once response finishes, closes, or errors
    let slotReleased = false;
    const releaseConcurrencySlot = () => {
      if (!slotReleased) {
        slotReleased = true;
        AiCostGuardService.releaseConcurrencySlot(userId).catch((err) => {
          logger.warn('[aiCostGuard] Failed to release slot in callback', { error: err.message });
        });
      }
    };

    res.once('finish', releaseConcurrencySlot);
    res.once('close', releaseConcurrencySlot);

    // 6. Set Telemetry and Budget Headers
    res.setHeader('X-AI-Plan', plan);
    res.setHeader('X-AI-Daily-Budget-Limit', budgetStatus.dailyBudget.toFixed(2));
    res.setHeader('X-AI-Daily-Budget-Remaining', budgetStatus.dailyRemaining.toFixed(4));
    res.setHeader('X-AI-Max-Tokens', limits.max_tokens.toString());
    res.setHeader('X-AI-Max-Concurrency', limits.max_concurrent_jobs.toString());

    next();
  } catch (error) {
    next(error);
  }
};
