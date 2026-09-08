import { Request, Response, NextFunction } from 'express';
import { AiCostGuardService } from '../services/ai_cost_guard.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { BadRequestError } from '../utils/apiError.js';
import { supabaseAdmin } from '../config/supabase.js';
import { AiPlanTier } from '../types/ai_cost.types.js';

export class AdminAiController {
  /**
   * GET /api/admin/ai/usage
   * Telemetry analytics, requests volume, input/output tokens, feature & provider distribution
   */
  public static async getAiUsage(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const period = req.query.period as string | undefined;
      const startDate = req.query.startDate as string | undefined;
      const endDate = req.query.endDate as string | undefined;
      const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 50;
      const offset = req.query.offset ? parseInt(req.query.offset as string, 10) : 0;

      const usageReport = await AiCostGuardService.getUsageReport({
        period,
        startDate,
        endDate,
        limit,
        offset,
      });

      ResponseFormatter.success(res, usageReport, 'AI telemetry usage data retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/admin/ai/cost
   * Financial analytics, total cost (USD), provider costs, daily trends, top spenders, alerts
   */
  public static async getAiCost(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const period = req.query.period as string | undefined;
      const startDate = req.query.startDate as string | undefined;
      const endDate = req.query.endDate as string | undefined;

      const costReport = await AiCostGuardService.getCostReport({
        period,
        startDate,
        endDate,
      });

      ResponseFormatter.success(res, costReport, 'AI cost and expenditure report retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/admin/ai/limits
   * View configurable limits for Free and Premium tiers
   */
  public static async getAiLimits(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const [freeLimits, premiumLimits] = await Promise.all([
        AiCostGuardService.getLimits('free'),
        AiCostGuardService.getLimits('premium'),
      ]);

      ResponseFormatter.success(
        res,
        { free: freeLimits, premium: premiumLimits },
        'AI cost and concurrency limits retrieved successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/admin/ai/limits/:plan
   * Update configurable limits for a plan tier
   */
  public static async updateAiLimits(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const plan = req.params.plan?.toLowerCase() as AiPlanTier;
      if (plan !== 'free' && plan !== 'premium') {
        throw new BadRequestError('Plan must be either "free" or "premium"');
      }

      const updated = await AiCostGuardService.updateLimits(plan, req.body);

      const { AuditService } = await import('../services/audit.service.js');
      await AuditService.logAction({
        actorId: req.profile?.id || null,
        action: 'limit_changed',
        resourceType: 'ai_limit',
        resourceId: plan,
        ipAddress: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || req.ip,
        userAgent: req.headers['user-agent'] as string,
        changes: req.body,
      });

      ResponseFormatter.success(res, updated, `AI limits updated successfully for ${plan.toUpperCase()}`);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/admin/ai/alerts
   * Active and historical AI spending alerts
   */
  public static async getAiAlerts(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const unackOnly = req.query.unacknowledged === 'true';
      let query = supabaseAdmin
        .from('ai_spending_alerts')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (unackOnly) {
        query = query.eq('acknowledged', false);
      }

      const { data, error } = await query;
      if (error) {
        throw error;
      }

      ResponseFormatter.success(res, data || [], 'AI spending alerts retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/admin/ai/alerts/:id/acknowledge
   * Acknowledge spending alert
   */
  public static async acknowledgeAlert(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const alertId = req.params.id;
      const adminId = req.user?.id;

      const { error } = await supabaseAdmin
        .from('ai_spending_alerts')
        .update({
          acknowledged: true,
          acknowledged_by: adminId,
          acknowledged_at: new Date().toISOString(),
        })
        .eq('id', alertId);

      if (error) {
        throw error;
      }

      ResponseFormatter.success(res, { acknowledged: true }, 'Alert acknowledged successfully');
    } catch (error) {
      next(error);
    }
  }
}
