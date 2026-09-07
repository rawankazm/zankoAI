// ==============================================================================
// ZankoAI Subscription Controller
// ==============================================================================

import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { SubscriptionService } from '../services/subscription.service.js';
import { checkoutSchema } from '../validators/subscription.validators.js';
import { UnauthorizedError } from '../utils/apiError.js';

export class SubscriptionController {
  /**
   * GET /api/subscription
   * Returns current subscription status and active plan.
   */
  static async getSubscription(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to fetch subscription');
    }

    const subscription = await SubscriptionService.getSubscription(userId);
    return ResponseFormatter.success(res, subscription, 'Subscription status retrieved');
  }

  /**
   * POST /api/subscription/checkout
   * Initiates a verified checkout with the requested payment provider.
   */
  static async createCheckout(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    const userEmail = (req as any).user?.email || (req as any).profile?.email;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to initiate checkout');
    }

    const validated = checkoutSchema.parse(req.body);
    const checkout = await SubscriptionService.createCheckout({
      userId,
      userEmail,
      plan: validated.plan,
      providerName: validated.provider,
      returnUrl: validated.returnUrl,
      cancelUrl: validated.cancelUrl,
    });

    return ResponseFormatter.created(res, checkout, 'Checkout session created');
  }

  /**
   * GET /api/subscription/history
   * Retrieves user subscription history, payment history, and event audit history.
   */
  static async getHistory(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to fetch subscription history');
    }

    const history = await SubscriptionService.getSubscriptionHistory(userId);
    return ResponseFormatter.success(res, history, 'Subscription history retrieved successfully');
  }

  /**
   * POST /api/subscription/cancel
   * Cancels active recurring subscription at period end or immediately.
   */
  static async cancelSubscription(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to cancel subscription');
    }

    const immediate = req.body?.immediate === true;
    const result = await SubscriptionService.cancelSubscription(userId, { immediate });
    return ResponseFormatter.success(res, result, result.message);
  }

  /**
   * POST /api/subscription/maintenance
   * Triggers subscription maintenance execution on-demand.
   */
  static async runMaintenance(req: Request, res: Response): Promise<Response> {
    const result = await SubscriptionService.runMaintenance();
    return ResponseFormatter.success(res, result, 'Subscription maintenance executed successfully');
  }

  /**
   * POST /api/subscription/restore
   * Restores subscription through direct server-to-server provider verification.
   */
  static async restoreSubscription(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to restore subscription');
    }

    const status = await SubscriptionService.restoreSubscription(userId);
    return ResponseFormatter.success(res, status, 'Subscription restoration processed');
  }

  /**
   * POST /api/subscription/webhook/:provider
   * Public webhook endpoint for payment providers.
   */
  static async handleWebhook(req: Request, res: Response): Promise<Response> {
    const provider = req.params.provider;
    const result = await SubscriptionService.processWebhook(
      provider,
      req.headers as Record<string, string>,
      req.body
    );

    return ResponseFormatter.success(res, result, 'Webhook processed successfully');
  }
}
