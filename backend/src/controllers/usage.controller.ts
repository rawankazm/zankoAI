import { Request, Response } from 'express';
import { UsageService } from '../services/usage.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { BadRequestError } from '../utils/apiError.js';

export class UsageController {
  /**
   * GET /api/usage/status
   * Returns current user's authoritative plan, active feature usage counts, limits, and reset times.
   */
  static async getStatus(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const summary = await UsageService.getUserUsageStatus(userId);
    return ResponseFormatter.success(res, summary, 'Usage status retrieved successfully');
  }

  /**
   * POST /api/usage/check
   * Dry-run quota check before the client begins a resource-heavy action.
   */
  static async checkQuota(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { feature } = req.body;

    if (!feature || typeof feature !== 'string') {
      throw new BadRequestError('Feature name is required');
    }

    const check = await UsageService.checkQuota(userId, feature);
    return ResponseFormatter.success(res, check, 'Quota check evaluated');
  }
}
