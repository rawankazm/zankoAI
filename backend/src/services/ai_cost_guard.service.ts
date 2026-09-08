import { redis } from '../config/redis.js';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { AppError } from '../utils/apiError.js';
import {
  AiCostLimits,
  AiPlanTier,
  AiRequestLogData,
  AiUsageSummaryResponse,
  AiCostSummaryResponse,
  UserAiBudgetStatus,
  AiSpendingAlert,
} from '../types/ai_cost.types.js';

// Authoritative Fallback Defaults (matches SQL migration seeds)
const DEFAULT_LIMITS: Record<AiPlanTier, AiCostLimits> = {
  free: {
    plan: 'free',
    max_request_chars: 3000,
    max_tokens: 1000,
    max_daily_cost_usd: 0.05,
    max_monthly_cost_usd: 0.50,
    max_concurrent_jobs: 1,
    rate_limit_per_min: 10,
    description: 'Free tier limits',
  },
  premium: {
    plan: 'premium',
    max_request_chars: 20000,
    max_tokens: 4000,
    max_daily_cost_usd: 2.00,
    max_monthly_cost_usd: 20.00,
    max_concurrent_jobs: 5,
    rate_limit_per_min: 60,
    description: 'Premium tier limits',
  },
};

// System-wide spend alert thresholds (in USD)
const SYSTEM_DAILY_ALERT_THRESHOLDS = [10.0, 50.0, 100.0, 250.0];

export class AiCostGuardService {
  private static limitsCache: Map<AiPlanTier, { data: AiCostLimits; expiresAt: number }> = new Map();
  private static readonly CACHE_TTL_MS = 60 * 1000; // 1 minute local in-memory TTL

  /**
   * NEVER EXPOSE PROVIDER API KEYS:
   * Scrubs sensitive API keys (Gemini, OpenAI, Anthropic) from any text, error message, or log.
   */
  public static sanitizeSecrets(input: string | null | undefined): string {
    if (!input) return '';
    let sanitized = String(input);

    // Redact known environment variables if present
    const envKeys = [
      process.env.GEMINI_API_KEY,
      process.env.OPENAI_API_KEY,
      process.env.ANTHROPIC_API_KEY,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
    ].filter(Boolean) as string[];

    for (const key of envKeys) {
      if (key && key.length > 5) {
        sanitized = sanitized.split(key).join('[REDACTED_API_KEY]');
      }
    }

    // Generic pattern sanitization
    // 1. Google Gemini keys: AIzaSy... (39 chars)
    sanitized = sanitized.replace(/AIzaSy[A-Za-z0-9_-]{33}/g, '[REDACTED_GEMINI_KEY]');
    // 2. OpenAI keys: sk-...
    sanitized = sanitized.replace(/sk-[A-Za-z0-9_-]{20,}/g, '[REDACTED_OPENAI_KEY]');
    // 3. Anthropic keys: sk-ant-...
    sanitized = sanitized.replace(/sk-ant-[A-Za-z0-9_-]{20,}/g, '[REDACTED_ANTHROPIC_KEY]');
    // 4. Bearer tokens in logs
    sanitized = sanitized.replace(/Bearer\s+[A-Za-z0-9._-]{20,}/gi, 'Bearer [REDACTED_TOKEN]');

    return sanitized;
  }

  /**
   * Fetch authoritative configurable limits for a plan tier
   */
  public static async getLimits(plan: AiPlanTier = 'free'): Promise<AiCostLimits> {
    const normalizedPlan: AiPlanTier = plan === 'premium' ? 'premium' : 'free';
    const now = Date.now();
    const cached = this.limitsCache.get(normalizedPlan);

    if (cached && cached.expiresAt > now) {
      return cached.data;
    }

    try {
      // 1. Check Redis
      const redisKey = `ai:limits:${normalizedPlan}`;
      const redisData = await redis.get(redisKey);
      if (redisData) {
        const parsed = JSON.parse(redisData) as AiCostLimits;
        this.limitsCache.set(normalizedPlan, { data: parsed, expiresAt: now + this.CACHE_TTL_MS });
        return parsed;
      }

      // 2. Check Supabase DB
      const { data, error } = await supabaseAdmin
        .from('ai_cost_limits')
        .select('*')
        .eq('plan', normalizedPlan)
        .maybeSingle();

      if (data && !error) {
        const limits: AiCostLimits = {
          plan: normalizedPlan,
          max_request_chars: Number(data.max_request_chars),
          max_tokens: Number(data.max_tokens),
          max_daily_cost_usd: Number(data.max_daily_cost_usd),
          max_monthly_cost_usd: Number(data.max_monthly_cost_usd),
          max_concurrent_jobs: Number(data.max_concurrent_jobs),
          rate_limit_per_min: Number(data.rate_limit_per_min),
          description: data.description,
          updated_at: data.updated_at,
        };

        // Cache in Redis for 10 minutes
        await redis.set(redisKey, JSON.stringify(limits), 'EX', 600);
        this.limitsCache.set(normalizedPlan, { data: limits, expiresAt: now + this.CACHE_TTL_MS });
        return limits;
      }
    } catch (err) {
      logger.warn('[AiCostGuard] Failed to fetch limits from DB/Redis, using defaults', {
        plan: normalizedPlan,
        error: (err as any)?.message,
      });
    }

    const fallback = DEFAULT_LIMITS[normalizedPlan];
    this.limitsCache.set(normalizedPlan, { data: fallback, expiresAt: now + this.CACHE_TTL_MS });
    return fallback;
  }

  /**
   * Validates request size against tier maximum
   */
  public static async validateRequestSize(textLength: number, plan: AiPlanTier = 'free'): Promise<void> {
    const limits = await this.getLimits(plan);
    if (textLength > limits.max_request_chars) {
      throw new AppError(
        `AI request payload exceeds allowed limit of ${limits.max_request_chars.toLocaleString()} characters for ${plan.toUpperCase()} tier (received: ${textLength.toLocaleString()} characters). Please shorten your input or upgrade your plan.`,
        413,
        'AI_PAYLOAD_TOO_LARGE',
        true,
        {
          plan,
          limitChars: limits.max_request_chars,
          receivedChars: textLength,
        }
      );
    }
  }

  /**
   * Validates requested tokens against tier limits
   */
  public static async validateTokenLimit(requestedTokens: number, plan: AiPlanTier = 'free'): Promise<number> {
    const limits = await this.getLimits(plan);
    if (requestedTokens > limits.max_tokens) {
      throw new AppError(
        `Requested tokens (${requestedTokens}) exceeds tier limit of ${limits.max_tokens} tokens for ${plan.toUpperCase()} tier.`,
        400,
        'AI_TOKEN_LIMIT_EXCEEDED',
        true,
        {
          plan,
          maxTokens: limits.max_tokens,
          requestedTokens,
        }
      );
    }
    return requestedTokens;
  }

  /**
   * Concurrency slot acquire with atomic Redis lock and automatic expiry
   */
  public static async acquireConcurrencySlot(userId: string, plan: AiPlanTier = 'free'): Promise<number> {
    const limits = await this.getLimits(plan);
    const key = `ai:concurrency:${userId}`;

    try {
      const activeSlots = await redis.incr(key);

      // Set safety expiration (120 seconds) on first increment so slots never leak indefinitely
      if (activeSlots === 1) {
        await redis.expire(key, 120);
      }

      if (activeSlots > limits.max_concurrent_jobs) {
        // Atomic rollback
        await redis.decr(key);
        throw new AppError(
          `AI concurrency limit reached (${limits.max_concurrent_jobs} concurrent job allowed for ${plan.toUpperCase()} plan). Please wait for your existing request to finish.`,
          429,
          'AI_CONCURRENT_LIMIT_EXCEEDED',
          true,
          {
            plan,
            maxConcurrentJobs: limits.max_concurrent_jobs,
            activeJobs: activeSlots,
          }
        );
      }

      return activeSlots;
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      logger.warn('[AiCostGuard] Redis concurrency check failed, failing open safely', { error: err.message });
      return 1;
    }
  }

  /**
   * Release concurrency slot atomically
   */
  public static async releaseConcurrencySlot(userId: string): Promise<void> {
    const key = `ai:concurrency:${userId}`;
    try {
      const val = await redis.decr(key);
      if (val <= 0) {
        await redis.del(key);
      }
    } catch (err: any) {
      logger.warn('[AiCostGuard] Failed to release concurrency slot', { userId, error: err.message });
    }
  }

  /**
   * Evaluates user's cumulative daily & monthly spending against configured budgets
   */
  public static async getBudgetStatus(userId: string, plan: AiPlanTier = 'free'): Promise<UserAiBudgetStatus> {
    const limits = await this.getLimits(plan);
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const month = today.substring(0, 7); // YYYY-MM

    const dailyKey = `ai:cost:daily:${userId}:${today}`;
    const monthlyKey = `ai:cost:monthly:${userId}:${month}`;
    const concurrencyKey = `ai:concurrency:${userId}`;

    let dailyCost = 0;
    let monthlyCost = 0;
    let activeConcurrentJobs = 0;

    try {
      const [dailyVal, monthlyVal, activeVal] = await Promise.all([
        redis.get(dailyKey),
        redis.get(monthlyKey),
        redis.get(concurrencyKey),
      ]);

      if (dailyVal !== null) {
        dailyCost = parseFloat(dailyVal) || 0;
      } else {
        // Fallback aggregate from DB for today
        const startOfDay = `${today}T00:00:00.000Z`;
        const { data } = await supabaseAdmin
          .from('ai_requests')
          .select('estimated_cost')
          .eq('user_id', userId)
          .gte('created_at', startOfDay);

        dailyCost = data ? data.reduce((acc, row) => acc + Number(row.estimated_cost || 0), 0) : 0;
        await redis.set(dailyKey, dailyCost.toString(), 'EX', 86400 * 2);
      }

      if (monthlyVal !== null) {
        monthlyCost = parseFloat(monthlyVal) || 0;
      } else {
        // Fallback aggregate from DB for this month
        const startOfMonth = `${month}-01T00:00:00.000Z`;
        const { data } = await supabaseAdmin
          .from('ai_requests')
          .select('estimated_cost')
          .eq('user_id', userId)
          .gte('created_at', startOfMonth);

        monthlyCost = data ? data.reduce((acc, row) => acc + Number(row.estimated_cost || 0), 0) : 0;
        await redis.set(monthlyKey, monthlyCost.toString(), 'EX', 86400 * 35);
      }

      activeConcurrentJobs = parseInt(activeVal || '0', 10) || 0;
    } catch (err: any) {
      logger.warn('[AiCostGuard] Budget status lookup failed, using 0', { error: err.message });
    }

    return {
      userId,
      plan,
      dailyCost: Math.round(dailyCost * 1000000) / 1000000,
      dailyBudget: limits.max_daily_cost_usd,
      dailyRemaining: Math.max(0, Math.round((limits.max_daily_cost_usd - dailyCost) * 1000000) / 1000000),
      monthlyCost: Math.round(monthlyCost * 1000000) / 1000000,
      monthlyBudget: limits.max_monthly_cost_usd,
      monthlyRemaining: Math.max(0, Math.round((limits.max_monthly_cost_usd - monthlyCost) * 1000000) / 1000000),
      activeConcurrentJobs,
      maxConcurrentJobs: limits.max_concurrent_jobs,
    };
  }

  /**
   * Pre-check budgets before executing AI operations
   */
  public static async checkBudgets(
    userId: string,
    plan: AiPlanTier = 'free',
    estimatedCost = 0
  ): Promise<UserAiBudgetStatus> {
    const status = await this.getBudgetStatus(userId, plan);

    // 1. Daily Budget Check
    if (status.dailyCost + estimatedCost >= status.dailyBudget) {
      // Trigger threshold alert
      await this.triggerAlert({
        user_id: userId,
        alert_type: 'user_daily_threshold',
        threshold_value: status.dailyBudget,
        current_value: status.dailyCost,
        severity: 'critical',
        message: `User ${userId} on ${plan.toUpperCase()} reached 100% of daily AI cost budget ($${status.dailyCost.toFixed(4)} / $${status.dailyBudget.toFixed(2)})`,
        metadata: { plan, estimatedCost, status },
      });

      // Record blocked log for telemetry
      await this.recordAiRequest({
        user_id: userId,
        feature: 'guardrail',
        provider: 'system',
        model: 'cost_guard',
        input_tokens: 0,
        output_tokens: 0,
        estimated_cost: 0,
        duration: 0,
        status: 'blocked',
        created_at: new Date().toISOString(),
        error_message: 'Daily AI budget limit exceeded',
      });

      throw new AppError(
        `Daily AI cost budget reached ($${status.dailyCost.toFixed(4)} / $${status.dailyBudget.toFixed(2)} limit for ${plan.toUpperCase()} plan). Limit resets at midnight UTC.`,
        429,
        'AI_DAILY_BUDGET_EXCEEDED',
        true,
        {
          plan,
          dailyCost: status.dailyCost,
          dailyBudget: status.dailyBudget,
          resetAt: '00:00 UTC',
        }
      );
    }

    // 2. Monthly Budget Check
    if (status.monthlyCost + estimatedCost >= status.monthlyBudget) {
      await this.triggerAlert({
        user_id: userId,
        alert_type: 'user_monthly_threshold',
        threshold_value: status.monthlyBudget,
        current_value: status.monthlyCost,
        severity: 'critical',
        message: `User ${userId} on ${plan.toUpperCase()} reached 100% of monthly AI cost budget ($${status.monthlyCost.toFixed(4)} / $${status.monthlyBudget.toFixed(2)})`,
        metadata: { plan, estimatedCost, status },
      });

      await this.recordAiRequest({
        user_id: userId,
        feature: 'guardrail',
        provider: 'system',
        model: 'cost_guard',
        input_tokens: 0,
        output_tokens: 0,
        estimated_cost: 0,
        duration: 0,
        status: 'blocked',
        created_at: new Date().toISOString(),
        error_message: 'Monthly AI budget limit exceeded',
      });

      throw new AppError(
        `Monthly AI cost budget reached ($${status.monthlyCost.toFixed(4)} / $${status.monthlyBudget.toFixed(2)} limit for ${plan.toUpperCase()} plan). Resets on the first of next month.`,
        429,
        'AI_MONTHLY_BUDGET_EXCEEDED',
        true,
        {
          plan,
          monthlyCost: status.monthlyCost,
          monthlyBudget: status.monthlyBudget,
        }
      );
    }

    return status;
  }

  /**
   * Tracks and records every AI request with all 10 required fields:
   * user_id, feature, provider, model, input_tokens, output_tokens, estimated_cost, duration, status, created_at
   */
  public static async recordAiRequest(data: AiRequestLogData): Promise<void> {
    const cleanError = this.sanitizeSecrets(data.error_message);
    const now = new Date().toISOString();

    const recordToInsert = {
      user_id: data.user_id,
      feature: data.feature || 'ai_chat',
      provider: data.provider || 'unknown',
      model: data.model || 'unknown',
      input_tokens: data.input_tokens || 0,
      output_tokens: data.output_tokens || 0,
      tokens: (data.input_tokens || 0) + (data.output_tokens || 0),
      prompt_tokens: data.input_tokens || 0,
      completion_tokens: data.output_tokens || 0,
      estimated_cost: data.estimated_cost || 0,
      duration: data.duration || 0,
      status: data.status,
      error_message: cleanError ? cleanError.substring(0, 1000) : null,
      created_at: data.created_at || now,
      completed_at: data.completed_at || now,
    };

    // 1. Insert into Supabase ai_requests table asynchronously
    supabaseAdmin
      .from('ai_requests')
      .insert(recordToInsert)
      .then(({ error }) => {
        if (error) {
          logger.warn('[AiCostGuard] Failed to record ai_requests entry', { error: error.message });
        }
      })
      .catch((err) => {
        logger.warn('[AiCostGuard] Unexpected error saving ai_requests entry', { error: err.message });
      });

    // 2. If request has monetary cost, atomically increment Redis tracking counters
    if (data.estimated_cost > 0) {
      const today = (data.created_at || now).split('T')[0];
      const month = today.substring(0, 7);
      const costStr = data.estimated_cost.toString();

      try {
        const dailyKey = `ai:cost:daily:${data.user_id}:${today}`;
        const monthlyKey = `ai:cost:monthly:${data.user_id}:${month}`;
        const systemDailyKey = `ai:system:cost:daily:${today}`;

        const [newDailyUserCost, , newSystemDailyCost] = await Promise.all([
          redis.incrbyfloat(dailyKey, costStr),
          redis.incrbyfloat(monthlyKey, costStr),
          redis.incrbyfloat(systemDailyKey, costStr),
        ]);

        // Ensure key TTLs
        await Promise.all([
          redis.expire(dailyKey, 86400 * 2),
          redis.expire(monthlyKey, 86400 * 35),
          redis.expire(systemDailyKey, 86400 * 3),
        ]);

        // 3. Evaluate System Daily Alert Thresholds
        const currentSystemSpend = parseFloat(newSystemDailyCost) || 0;
        for (const threshold of SYSTEM_DAILY_ALERT_THRESHOLDS) {
          if (currentSystemSpend >= threshold && currentSystemSpend - data.estimated_cost < threshold) {
            await this.triggerAlert({
              user_id: null,
              alert_type: 'system_daily_threshold',
              threshold_value: threshold,
              current_value: currentSystemSpend,
              severity: threshold >= 100 ? 'critical' : 'warning',
              message: `System-wide daily AI spend crossed $${threshold.toFixed(2)} USD (Current spend: $${currentSystemSpend.toFixed(4)} USD)`,
              metadata: { today, currentSystemSpend, threshold },
            });
          }
        }
      } catch (redisErr: any) {
        logger.warn('[AiCostGuard] Failed to update Redis cost aggregations', { error: redisErr.message });
      }
    }
  }

  /**
   * Records spending alerts in database and logs
   */
  public static async triggerAlert(alert: {
    user_id?: string | null;
    alert_type: string;
    threshold_value: number;
    current_value: number;
    severity: 'info' | 'warning' | 'critical';
    message: string;
    metadata?: Record<string, any>;
  }): Promise<void> {
    logger.warn(`[AiSpendingAlert] ${alert.severity.toUpperCase()}: ${alert.message}`, {
      user_id: alert.user_id,
      threshold: alert.threshold_value,
      current: alert.current_value,
    });

    try {
      await supabaseAdmin.from('ai_spending_alerts').insert({
        user_id: alert.user_id || null,
        alert_type: alert.alert_type,
        threshold_value: alert.threshold_value,
        current_value: alert.current_value,
        severity: alert.severity,
        message: alert.message,
        metadata: alert.metadata || {},
      });
    } catch (err: any) {
      logger.warn('[AiCostGuard] Failed to persist spending alert', { error: err.message });
    }
  }

  /**
   * Admin Analytics: Aggregated AI Usage Report
   */
  public static async getUsageReport(filters: {
    period?: string;
    startDate?: string;
    endDate?: string;
    limit?: number;
    offset?: number;
  }): Promise<AiUsageSummaryResponse> {
    const limit = Math.min(filters.limit || 50, 100);
    const offset = filters.offset || 0;

    let query = supabaseAdmin.from('ai_requests').select('*', { count: 'exact' });

    if (filters.startDate) {
      query = query.gte('created_at', filters.startDate);
    } else if (filters.period === 'today') {
      const today = new Date().toISOString().split('T')[0];
      query = query.gte('created_at', `${today}T00:00:00.000Z`);
    } else if (filters.period === 'week') {
      const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();
      query = query.gte('created_at', weekAgo);
    } else if (filters.period === 'month') {
      const monthAgo = new Date(Date.now() - 30 * 86400000).toISOString();
      query = query.gte('created_at', monthAgo);
    }

    if (filters.endDate) {
      query = query.lte('created_at', filters.endDate);
    }

    // Fetch aggregate window
    const { data: rows, count, error } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new AppError(`Failed to fetch AI usage telemetry: ${error.message}`, 500);
    }

    const items = rows || [];
    let totalTokens = 0;
    let totalInputTokens = 0;
    let totalOutputTokens = 0;
    let totalDuration = 0;
    let successCount = 0;
    let failedCount = 0;
    let timeoutCount = 0;
    let blockedCount = 0;

    const byFeature: Record<string, { requests: number; tokens: number; cost_usd: number }> = {};
    const byProvider: Record<string, { requests: number; tokens: number; cost_usd: number }> = {};
    const byModel: Record<string, { requests: number; tokens: number; cost_usd: number }> = {};
    const userMap: Map<string, { count: number; tokens: number; cost: number }> = new Map();

    for (const item of items) {
      const inTok = Number(item.input_tokens || item.prompt_tokens || 0);
      const outTok = Number(item.output_tokens || item.completion_tokens || 0);
      const tok = Number(item.tokens || inTok + outTok);
      const cost = Number(item.estimated_cost || 0);
      const dur = Number(item.duration || 0);

      totalTokens += tok;
      totalInputTokens += inTok;
      totalOutputTokens += outTok;
      totalDuration += dur;

      if (item.status === 'success') successCount++;
      else if (item.status === 'failed') failedCount++;
      else if (item.status === 'timeout') timeoutCount++;
      else if (item.status === 'blocked') blockedCount++;

      // Feature breakdown
      const feat = item.feature || 'unknown';
      if (!byFeature[feat]) byFeature[feat] = { requests: 0, tokens: 0, cost_usd: 0 };
      byFeature[feat].requests++;
      byFeature[feat].tokens += tok;
      byFeature[feat].cost_usd += cost;

      // Provider breakdown
      const prov = item.provider || 'unknown';
      if (!byProvider[prov]) byProvider[prov] = { requests: 0, tokens: 0, cost_usd: 0 };
      byProvider[prov].requests++;
      byProvider[prov].tokens += tok;
      byProvider[prov].cost_usd += cost;

      // Model breakdown
      const mod = item.model || 'unknown';
      if (!byModel[mod]) byModel[mod] = { requests: 0, tokens: 0, cost_usd: 0 };
      byModel[mod].requests++;
      byModel[mod].tokens += tok;
      byModel[mod].cost_usd += cost;

      // User aggregation
      const uid = item.user_id;
      const current = userMap.get(uid) || { count: 0, tokens: 0, cost: 0 };
      current.count++;
      current.tokens += tok;
      current.cost += cost;
      userMap.set(uid, current);
    }

    const topUsers = Array.from(userMap.entries())
      .map(([user_id, stats]) => ({
        user_id,
        request_count: stats.count,
        total_tokens: stats.tokens,
        total_cost: Math.round(stats.cost * 1000000) / 1000000,
      }))
      .sort((a, b) => b.total_cost - a.total_cost)
      .slice(0, 10);

    return {
      total_requests: count || items.length,
      success_requests: successCount,
      failed_requests: failedCount,
      timeout_requests: timeoutCount,
      blocked_requests: blockedCount,
      total_tokens: totalTokens,
      total_input_tokens: totalInputTokens,
      total_output_tokens: totalOutputTokens,
      avg_duration_ms: items.length > 0 ? Math.round(totalDuration / items.length) : 0,
      breakdown_by_feature: byFeature,
      breakdown_by_provider: byProvider,
      breakdown_by_model: byModel,
      breakdown_by_tier: {
        free: { requests: 0, tokens: 0, cost_usd: 0 },
        premium: { requests: 0, tokens: 0, cost_usd: 0 },
      },
      top_users: topUsers,
      recent_requests: items.slice(0, limit).map((r) => ({
        id: r.id,
        user_id: r.user_id,
        feature: r.feature,
        provider: r.provider,
        model: r.model,
        input_tokens: r.input_tokens || r.prompt_tokens || 0,
        output_tokens: r.output_tokens || r.completion_tokens || 0,
        estimated_cost: Number(r.estimated_cost || 0),
        duration: r.duration,
        status: r.status,
        created_at: r.created_at,
        error_message: r.error_message,
      })),
      timeframe: filters,
    };
  }

  /**
   * Admin Analytics: Comprehensive AI Financial Cost Audit
   */
  public static async getCostReport(filters: {
    period?: string;
    startDate?: string;
    endDate?: string;
  }): Promise<AiCostSummaryResponse> {
    let query = supabaseAdmin.from('ai_requests').select('*');

    const now = new Date();
    let filterStart = filters.startDate;

    if (!filterStart) {
      if (filters.period === 'today') {
        filterStart = `${now.toISOString().split('T')[0]}T00:00:00.000Z`;
      } else if (filters.period === 'week') {
        filterStart = new Date(Date.now() - 7 * 86400000).toISOString();
      } else {
        // default 30 days
        filterStart = new Date(Date.now() - 30 * 86400000).toISOString();
      }
    }

    query = query.gte('created_at', filterStart);
    if (filters.endDate) {
      query = query.lte('created_at', filters.endDate);
    }

    const { data: rows, error } = await query.order('created_at', { ascending: false });

    if (error) {
      throw new AppError(`Failed to fetch AI cost report: ${error.message}`, 500);
    }

    const items = rows || [];
    let periodCost = 0;
    const costByProvider: Record<string, number> = {};
    const costByFeature: Record<string, number> = {};
    const dailyMap: Map<string, { cost: number; requests: number; tokens: number }> = new Map();
    const spenderMap: Map<string, { total: number; daily: number; monthly: number }> = new Map();

    const todayStr = now.toISOString().split('T')[0];
    const monthStr = todayStr.substring(0, 7);

    for (const item of items) {
      const cost = Number(item.estimated_cost || 0);
      const tokens = Number(item.tokens || 0);
      periodCost += cost;

      // By Provider
      const prov = item.provider || 'unknown';
      costByProvider[prov] = (costByProvider[prov] || 0) + cost;

      // By Feature
      const feat = item.feature || 'unknown';
      costByFeature[feat] = (costByFeature[feat] || 0) + cost;

      // Daily Trend Map
      const day = item.created_at.split('T')[0];
      const dayStats = dailyMap.get(day) || { cost: 0, requests: 0, tokens: 0 };
      dayStats.cost += cost;
      dayStats.requests++;
      dayStats.tokens += tokens;
      dailyMap.set(day, dayStats);

      // Spender Map
      const uid = item.user_id;
      const spender = spenderMap.get(uid) || { total: 0, daily: 0, monthly: 0 };
      spender.total += cost;
      if (day === todayStr) spender.daily += cost;
      if (day.startsWith(monthStr)) spender.monthly += cost;
      spenderMap.set(uid, spender);
    }

    // Format daily trend
    const dailyTrend = Array.from(dailyMap.entries())
      .map(([date, stats]) => ({
        date,
        cost_usd: Math.round(stats.cost * 10000) / 10000,
        request_count: stats.requests,
        tokens: stats.tokens,
      }))
      .sort((a, b) => a.date.localeCompare(b.date));

    // Top spenders
    const topSpenders = Array.from(spenderMap.entries())
      .map(([user_id, stats]) => ({
        user_id,
        plan: 'user',
        daily_cost: Math.round(stats.daily * 10000) / 10000,
        monthly_cost: Math.round(stats.monthly * 10000) / 10000,
        total_cost: Math.round(stats.total * 10000) / 10000,
      }))
      .sort((a, b) => b.total_cost - a.total_cost)
      .slice(0, 10);

    // Days spanned calculation for average
    const daysCount = Math.max(1, dailyTrend.length);
    const dailyAvg = periodCost / daysCount;
    const projectedMonthly = dailyAvg * 30;

    // Fetch active unacknowledged alerts
    const { data: alerts } = await supabaseAdmin
      .from('ai_spending_alerts')
      .select('*')
      .eq('acknowledged', false)
      .order('created_at', { ascending: false })
      .limit(20);

    return {
      total_cost_usd: Math.round(periodCost * 10000) / 10000,
      period_cost_usd: Math.round(periodCost * 10000) / 10000,
      daily_average_cost_usd: Math.round(dailyAvg * 10000) / 10000,
      projected_monthly_cost_usd: Math.round(projectedMonthly * 10000) / 10000,
      cost_by_provider: Object.fromEntries(
        Object.entries(costByProvider).map(([k, v]) => [k, Math.round(v * 10000) / 10000])
      ),
      cost_by_feature: Object.fromEntries(
        Object.entries(costByFeature).map(([k, v]) => [k, Math.round(v * 10000) / 10000])
      ),
      cost_by_tier: {
        free: 0,
        premium: Math.round(periodCost * 10000) / 10000,
      },
      daily_trend: dailyTrend,
      top_spenders: topSpenders,
      active_alerts: (alerts as any) || [],
      timeframe: filters,
    };
  }

  /**
   * Updates tier limits dynamically in database and resets cache
   */
  public static async updateLimits(plan: AiPlanTier, limits: Partial<AiCostLimits>): Promise<AiCostLimits> {
    const { error } = await supabaseAdmin
      .from('ai_cost_limits')
      .update({
        ...limits,
        updated_at: new Date().toISOString(),
      })
      .eq('plan', plan);

    if (error) {
      throw new AppError(`Failed to update AI cost limits: ${error.message}`, 500);
    }

    // Invalidate caches
    this.limitsCache.delete(plan);
    await redis.del(`ai:limits:${plan}`);

    return this.getLimits(plan);
  }
}
