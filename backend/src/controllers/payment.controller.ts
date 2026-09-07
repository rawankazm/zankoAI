// ==============================================================================
// ZankoAI Payment Controller
// ==============================================================================

import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { PaymentService } from '../services/payment.service.js';
import {
  createPaymentCheckoutSchema,
  refundPaymentSchema,
} from '../validators/payment.validators.js';
import { UnauthorizedError, NotFoundError } from '../utils/apiError.js';

export class PaymentController {
  /**
   * POST /api/payments/checkout
   * Initiates payment checkout with selected payment gateway.
   */
  static async createCheckout(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required to initiate payment');
    }

    const validated = createPaymentCheckoutSchema.parse(req.body);
    const checkout = await PaymentService.createCheckout({
      userId: userId,
      plan: validated.plan,
      providerName: validated.provider,
      returnUrl: validated.returnUrl,
      isRenewal: validated.isRenewal,
    });

    return ResponseFormatter.created(res, checkout, 'Payment checkout session created');
  }

  /**
   * GET /api/payments/:id
   * Retrieves payment status and details.
   */
  static async getPayment(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    const paymentId = req.params.id;

    const payment = await PaymentService.getPayment(paymentId, userId);
    if (!payment) {
      throw new NotFoundError('Payment transaction not found: ' + paymentId);
    }

    return ResponseFormatter.success(res, payment, 'Payment retrieved successfully');
  }

  /**
   * POST /api/payments/webhook/:provider
   * Inbound provider webhook callback. Validates signature, verifies status,
   * enforces idempotency, and activates subscription.
   */
  static async handleWebhook(req: Request, res: Response): Promise<Response> {
    const provider = req.params.provider;
    const result = await PaymentService.processWebhook(
      provider,
      req.headers as Record<string, string>,
      req.body
    );

    return res.status(200).json({
      success: true,
      received: true,
      duplicate: result.duplicate || false,
      status: result.status,
      orderId: result.orderId,
    });
  }

  /**
   * POST /api/payments/:id/refund
   * Refunds payment via provider.
   */
  static async refundPayment(req: Request, res: Response): Promise<Response> {
    const userId = (req as any).user?.id || (req as any).profile?.id;
    if (!userId) {
      throw new UnauthorizedError('Authentication required');
    }

    const paymentId = req.params.id;
    const validated = refundPaymentSchema.parse(req.body);
    const result = await PaymentService.refundPayment(paymentId, validated.reason);

    return ResponseFormatter.success(res, result, 'Payment refund processed');
  }
}
