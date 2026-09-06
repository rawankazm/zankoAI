import { Request, Response } from 'express';
import { AnalyticsService } from '../services/analytics.service.js';
import { CostMonitorService } from '../services/cost_monitor.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';

export class AdminAnalyticsController {
  /**
   * GET /api/admin/analytics/users
   * Returns authoritative user metrics distinguishing registered vs MAU
   */
  static async getUserAnalytics(req: Request, res: Response): Promise<Response> {
    const analytics = await AnalyticsService.getUserAnalytics();
    return ResponseFormatter.success(res, analytics, 'User analytics retrieved successfully');
  }

  /**
   * GET /api/admin/analytics/alerts
   * List active Supabase cost and MAU threshold alerts
   */
  static async getCostAlerts(req: Request, res: Response): Promise<Response> {
    const unacknowledgedOnly = req.query.unacknowledged !== 'false';
    const alerts = await CostMonitorService.listAlerts(unacknowledgedOnly);
    return ResponseFormatter.success(res, alerts, 'Cost alerts retrieved successfully');
  }

  /**
   * POST /api/admin/analytics/alerts/:id/acknowledge
   * Acknowledge an alert to dismiss from active dashboard
   */
  static async acknowledgeAlert(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const adminUserId = req.user?.id;
    const acknowledged = await CostMonitorService.acknowledgeAlert(id, adminUserId);
    return ResponseFormatter.success(res, { id, acknowledged }, 'Alert acknowledged successfully');
  }

  /**
   * GET /api/admin/analytics/thresholds
   * List all configurable MAU and cost thresholds
   */
  static async listThresholds(req: Request, res: Response): Promise<Response> {
    const thresholds = await CostMonitorService.listThresholds();
    return ResponseFormatter.success(res, thresholds, 'Thresholds retrieved successfully');
  }

  /**
   * PUT /api/admin/analytics/thresholds/:id
   * Update an existing threshold (e.g. adjust 50k to 60k)
   */
  static async updateThreshold(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const { threshold_value, severity, description } = req.body;
    const updated = await CostMonitorService.updateThreshold(id, {
      threshold_value,
      severity,
      description,
    });
    return ResponseFormatter.success(res, updated, 'Threshold updated successfully');
  }
}
