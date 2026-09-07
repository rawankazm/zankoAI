// ==============================================================================
// ZankoAI ZainCash Mobile Wallet Payment Provider Implementation
// ==============================================================================

import crypto from 'crypto';
import jwt from 'jsonwebtoken';
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

export class ZainCashPaymentProvider implements PaymentProvider {
  readonly name = 'zaincash';

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
    const orderId = 'zc_order_' + Date.now() + '_' + crypto.randomBytes(4).toString('hex');

    const tokenPayload = {
      amount,
      serviceType: 'ZankoAI ' + request.plan,
      msisdn: env.ZAINCASH_MSISDN || '9647800000000',
      orderId,
      redirectUrl: env.API_PREFIX + '/subscription/webhook/zaincash',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 4 * 60 * 60,
    };

    const secret = env.ZAINCASH_SECRET || 'zanko_zaincash_secret_2026';
    const signedJwt = jwt.sign(tokenPayload, secret);
    const checkoutUrl = 'https://api.zaincash.iq/transaction/pay?id=' + orderId + '&token=' + signedJwt;

    return {
      checkoutId: orderId,
      checkoutUrl,
      qrPayload: checkoutUrl,
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
    logger.info('ZainCash subscription canceled for ID: ' + providerSubscriptionId);
    return {
      success: true,
      canceledAt: new Date(),
    };
  }

  async handleWebhook(headers: Record<string, string>, rawBody: any): Promise<WebhookResult> {
    let payload = rawBody;

    // ZainCash sends signed JWT token in payload
    if (typeof rawBody === 'string') {
      try {
        payload = JSON.parse(rawBody);
      } catch {
        payload = { token: rawBody };
      }
    }

    if (payload.token) {
      try {
        const secret = env.ZAINCASH_SECRET || 'zanko_zaincash_secret_2026';
        payload = jwt.verify(payload.token, secret) as any;
      } catch (err: any) {
        throw new Error('ZainCash Webhook: invalid JWT signature - ' + err.message);
      }
    }

    const orderId = payload.orderId || payload.id || payload.ref;
    const status = (payload.status || 'success').toUpperCase();

    if (!orderId) {
      throw new Error('ZainCash Webhook: missing orderId');
    }

    const now = new Date();
    const periodEnd = new Date(now);
    const plan: SubscriptionPlanType = payload.plan || 'PREMIUM_MONTHLY';

    if (plan === 'PREMIUM_YEARLY') {
      periodEnd.setDate(periodEnd.getDate() + 365);
    } else {
      periodEnd.setDate(periodEnd.getDate() + 30);
    }

    const isPaid = status === 'SUCCESS' || status === 'PAID' || status === 'COMPLETED';
    const isFailed = status === 'FAILED' || status === 'CANCELED';

    let subscriptionStatus: any = 'incomplete';
    let eventType = 'payment.pending';

    if (isPaid) {
      subscriptionStatus = 'active';
      eventType = 'payment.succeeded';
    } else if (isFailed) {
      subscriptionStatus = 'past_due';
      eventType = 'payment.failed';
    }

    const idempotencyKey = 'zaincash_' + orderId + '_' + status.toLowerCase();

    return {
      handled: true,
      eventType,
      idempotencyKey,
      userId: payload.userId || payload.user_id,
      plan,
      status: subscriptionStatus,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      providerSubscriptionId: orderId,
      metadata: payload,
    };
  }
}
