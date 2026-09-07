// ==============================================================================
// ZankoAI FastPay Mobile Wallet Payment Provider Implementation
// ==============================================================================

import crypto from 'crypto';
import { PaymentProvider } from './payment_provider.interface.js';
import {
  CheckoutRequest,
  CheckoutResult,
  VerificationResult,
  WebhookResult,
  SubscriptionPlanType,
} from '../../types/subscription.types.js';
import { env } from '../../config/env.js';
import { logger } from '../../config/logger.js';

export class FastPayPaymentProvider implements PaymentProvider {
  readonly name = 'fastpay';

  private getPlanPriceIqd(plan: SubscriptionPlanType): number {
    switch (plan) {
      case 'PREMIUM_MONTHLY':
        return 15000;
      case 'PREMIUM_YEARLY':
        return 140000;
      case 'STUDENT':
        return 9000;
      case 'UNIVERSITY':
        return 500000;
      case 'TEAM':
        return 45000;
      case 'FREE':
      default:
        return 0;
    }
  }

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    const amount = this.getPlanPriceIqd(request.plan);
    const orderId = 'fp_order_' + Date.now() + '_' + crypto.randomBytes(4).toString('hex');
    const paymentUrl = 'https://secure.fast-pay.iq/checkout?order_id=' + orderId;
    const qrPayload = 'fastpay://merchant/pay?id=' + (env.FASTPAY_MERCHANT_ID || 'ZANKO') + '&order=' + orderId + '&amount=' + amount;

    return {
      checkoutId: orderId,
      checkoutUrl: paymentUrl,
      qrPayload,
      provider: this.name,
      plan: request.plan,
      amount,
      currency: 'IQD',
      expiresAt: new Date(Date.now() + 1800000).toISOString(),
    };
  }

  async verifyPayment(referenceId: string): Promise<VerificationResult> {
    const now = new Date();
    const periodEnd = new Date(now);
    periodEnd.setDate(periodEnd.getDate() + 30);

    return {
      verified: true,
      providerSubscriptionId: referenceId,
      plan: 'PREMIUM_MONTHLY',
      status: 'active',
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      amountPaid: 15000,
      currency: 'IQD',
    };
  }

  async getSubscription(providerSubscriptionId: string): Promise<VerificationResult> {
    return await this.verifyPayment(providerSubscriptionId);
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<{ success: boolean; canceledAt: Date }> {
    logger.info('FastPay subscription canceled for order: ' + providerSubscriptionId);
    return {
      success: true,
      canceledAt: new Date(),
    };
  }

  async handleWebhook(headers: Record<string, string>, rawBody: any): Promise<WebhookResult> {
    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const orderId = payload.order_id || payload.orderId || payload.ref;
    const status = (payload.status || '').toUpperCase();

    if (!orderId) {
      throw new Error('FastPay Webhook: missing order_id');
    }

    // Validate signature if secret provided
    if (payload.signature && env.FASTPAY_PASSWORD) {
      const expected = crypto
        .createHmac('sha256', env.FASTPAY_PASSWORD)
        .update(orderId + ':' + status)
        .digest('hex');
      if (payload.signature !== expected) {
        throw new Error('FastPay Webhook: invalid signature verification');
      }
    }

    const now = new Date();
    const periodEnd = new Date(now);
    const plan: SubscriptionPlanType = payload.plan || 'PREMIUM_MONTHLY';

    if (plan === 'PREMIUM_YEARLY') {
      periodEnd.setDate(periodEnd.getDate() + 365);
    } else {
      periodEnd.setDate(periodEnd.getDate() + 30);
    }

    const isPaid = status === 'PAID' || status === 'SUCCESS' || status === 'COMPLETED';
    const isFailed = status === 'FAILED' || status === 'EXPIRED';

    let subscriptionStatus: any = 'incomplete';
    let eventType = 'payment.pending';

    if (isPaid) {
      subscriptionStatus = 'active';
      eventType = 'payment.succeeded';
    } else if (isFailed) {
      subscriptionStatus = 'past_due';
      eventType = 'payment.failed';
    }

    const idempotencyKey = 'fastpay_' + orderId + '_' + status.toLowerCase();

    return {
      handled: true,
      eventType,
      idempotencyKey,
      userId: payload.user_id || payload.userId,
      plan,
      status: subscriptionStatus,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      providerSubscriptionId: orderId,
      metadata: payload,
    };
  }
}
