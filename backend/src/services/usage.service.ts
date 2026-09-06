import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { redis } from '../config/redis.js';
import { SecurityLogger } from '../utils/securityLogger.js';
import {
  FeatureName,
  PlanLimit,
  QuotaCheckResult,
  UpdatePlanLimitDto,
  CreatePlanLimitDto,
  UserUsageSummaryResponse,
} from '../types/usage.types.js';

// Centralized fallback matrix in case of database connectivity interruptions
// NEVER hardcoded in application logic; used purely for emergency degradation
const EMERGENCY_FALLBACK_LIMITS: Record<string, Record<string, { limit: number; period: 'daily' | 'monthly' }>> = {
  free: {
    ai_chat: { limit: 10, period: 'daily' },
    pdf: { limit: 3, period: 'monthly' },
    ocr: { limit: 10, period: 'monthly' },
    audio: { limit: 5, period: 'monthly' },
    homework: { limit: 10, period: 'daily' },
    quiz: { limit: 5, period: 'monthly' },
    flashcards: { limit: 5, period: 'monthly' },
    storage: { limit: 52428800, period: 'monthly' },
  },
  premium: {
    ai_chat: { limit: 500, period: 'daily' },
    pdf: { limit: 100, period: 'monthly' },
    ocr: { limit: 200, period: 'monthly' },
    audio: { limit: 100, period: 'monthly' },
    homework: { limit: 200, period: 'daily' },
    quiz: { limit: 200, period: 'monthly' },
    flashcards: { limit: 200, period: 'monthly' },
    storage: { limit: 5368709120, period: 'monthly' },
  },
};

export class UsageService {
  /**
   * Authoritatively consume quota on the server using PostgreSQL atomic transaction/RPC.
   * Prevents race conditions, double-counting, and client-side manipulation.
   */
  static async consumeQuota(
    userId: string,
    feature: FeatureName,
    increment: number = 1,
    idempotencyKey?: string
  ): Promise<QuotaCheckResult> {
    try {
      const { data, error } = await supabaseAdmin.rpc('consume_feature_quota', {
        p_user_id: userId,
        p_feature: feature,
        p_increment: increment,
        p_idempotency_key: idempotencyKey || null,
      });

      if (error) {
        logger.error(`consume_feature_quota RPC error for user ${userId}, feature ${feature}: ${error.message}`);
        return this.fallbackConsume(userId, feature, increment);
      }

      const result = data as QuotaCheckResult;

      if (!result.allowed) {
        SecurityLogger.log('QUOTA_EXCEEDED', 'INFO', 'BLOCKED', {
          userId,
          feature,
          plan: result.plan,
          currentUsage: result.current_usage,
          limit: result.limit,
        });
      }

      return result;
    } catch (err: any) {
      logger.error(`Exception during consumeQuota: ${err.message}`);
      return this.fallbackConsume(userId, feature, increment);
    }
  }

  /**
   * Dry-run check for a feature quota without incrementing usage.
   */
  static async checkQuota(userId: string, feature: FeatureName): Promise<QuotaCheckResult> {
    return this.consumeQuota(userId, feature, 0);
  }

  /**
   * Returns a complete breakdown of current usage, limits, and reset times across all features.
   */
  static async getUserUsageStatus(userId: string): Promise<UserUsageSummaryResponse> {
    try {
      const { data, error } = await supabaseAdmin.rpc('get_user_usage_status', {
        p_user_id: userId,
      });

      if (error) {
        logger.error(`get_user_usage_status RPC error for ${userId}: ${error.message}`);
        return this.fallbackSummary(userId);
      }

      return data as UserUsageSummaryResponse;
    } catch (err: any) {
      logger.error(`Exception in getUserUsageStatus: ${err.message}`);
      return this.fallbackSummary(userId);
    }
  }

  /**
   * Admin: List all configurable plan limits
   */
  static async listPlanLimits(): Promise<PlanLimit[]> {
    const { data, error } = await supabaseAdmin
      .from('plan_limits')
      .select('*')
      .order('plan')
      .order('feature');

    if (error) {
      logger.error(`Failed to list plan limits: ${error.message}`);
      throw new Error(`Failed to list plan limits: ${error.message}`);
    }

    return (data || []) as PlanLimit[];
  }

  /**
   * Admin: Update an existing plan limit dynamically
   */
  static async updatePlanLimit(id: string, updates: UpdatePlanLimitDto): Promise<PlanLimit> {
    const { data, error } = await supabaseAdmin
      .from('plan_limits')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      logger.error(`Failed to update plan limit ${id}: ${error.message}`);
      throw new Error(`Failed to update plan limit: ${error.message}`);
    }

    logger.info(`Plan limit ${id} updated successfully by admin`);
    return data as PlanLimit;
  }

  /**
   * Admin: Create a new custom feature plan limit
   */
  static async createPlanLimit(dto: CreatePlanLimitDto): Promise<PlanLimit> {
    const { data, error } = await supabaseAdmin
      .from('plan_limits')
      .insert({
        ...dto,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) {
      logger.error(`Failed to create plan limit: ${error.message}`);
      throw new Error(`Failed to create plan limit: ${error.message}`);
    }

    logger.info(`Plan limit created successfully for ${dto.plan}:${dto.feature}`);
    return data as PlanLimit;
  }

  // ─── Emergency Resilience Fallbacks ───

  private static async fallbackConsume(
    userId: string,
    feature: FeatureName,
    increment: number
  ): Promise<QuotaCheckResult> {
    // Attempt Redis sliding window fallback
    try {
      const today = new Date().toISOString().split('T')[0];
      const redisKey = `quota_fallback:${userId}:${feature}:${today}`;
      const count = await redis.incrby(redisKey, increment);
      if (count === increment) {
        await redis.expire(redisKey, 86400);
      }

      const defaultLimit = EMERGENCY_FALLBACK_LIMITS.free[feature]?.limit || 10;
      const allowed = count <= defaultLimit;

      const tomorrow = new Date();
      tomorrow.setUTCHours(24, 0, 0, 0);

      return {
        allowed,
        code: allowed ? undefined : 'QUOTA_EXCEEDED',
        plan: 'free',
        feature,
        current_usage: count,
        limit: defaultLimit,
        remaining: Math.max(0, defaultLimit - count),
        reset_at: tomorrow.toISOString(),
        period_type: 'daily',
      };
    } catch {
      // If both Postgres and Redis fail, allow request under graceful degradation
      const tomorrow = new Date();
      tomorrow.setUTCHours(24, 0, 0, 0);
      return {
        allowed: true,
        plan: 'free',
        feature,
        current_usage: 1,
        limit: 10,
        remaining: 9,
        reset_at: tomorrow.toISOString(),
        period_type: 'daily',
      };
    }
  }

  private static fallbackSummary(userId: string): UserUsageSummaryResponse {
    const now = new Date();
    const tomorrow = new Date();
    tomorrow.setUTCHours(24, 0, 0, 0);

    const features: Record<string, any> = {};
    for (const [key, val] of Object.entries(EMERGENCY_FALLBACK_LIMITS.free)) {
      features[key] = {
        feature: key,
        period_type: val.period,
        current_usage: 0,
        limit: val.limit,
        remaining: val.limit,
        reset_at: tomorrow.toISOString(),
        description: `Emergency fallback limit for ${key}`,
      };
    }

    return {
      plan: 'free',
      is_vip: false,
      features,
      queried_at: now.toISOString(),
    };
  }
}
