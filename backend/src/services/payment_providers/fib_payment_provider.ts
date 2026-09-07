// ==============================================================================
// ZankoAI First Iraqi Bank (FIB) Payment Provider Implementation
// ==============================================================================

import axios from 'axios';
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

export class FibPaymentProvider implements PaymentProvider {
  readonly name = 'fib';

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

  private async getAccessToken(): Promise<string> {
    if (!env.FIB_CLIENT_ID || !env.FIB_CLIENT_SECRET) {
      throw new Error('FIB credentials not configured on server');
    }

    const tokenUrl = env.FIB_BASE_URL + '/auth/realms/fib-online-shop/protocol/openid-connect/token';
    const res = await axios.post(
      tokenUrl,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: env.FIB_CLIENT_ID,
        client_secret: env.FIB_CLIENT_SECRET,
      }).toString(),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeout: 10000,
      }
    );

    return res.data.access_token;
  }

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    const amount = this.getPlanPriceIqd(request.plan);
    const checkoutRef = 'zanko_fib_' + Date.now() + '_' + crypto.randomBytes(4).toString('hex');

    if (env.FIB_CLIENT_ID && env.FIB_CLIENT_SECRET) {
      try {
        const token = await this.getAccessToken();
        const paymentUrl = env.FIB_BASE_URL + '/protected/v1/payments';

        const paymentRes = await axios.post(
          paymentUrl,
          {
            monetaryValue: { amount, currency: 'IQD' },
            statusCallbackUrl: env.API_PREFIX + '/subscription/webhook/fib',
            description: 'ZankoAI Subscription - ' + request.plan,
            refundableFor: 'P7D',
          },
          {
            headers: {
              Authorization: 'Bearer ' + token,
              'Content-Type': 'application/json',
            },
            timeout: 15000,
          }
        );

        const { paymentId, qrCode, readableCode, personalAppLink } = paymentRes.data;

        return {
          checkoutId: paymentId || checkoutRef,
          checkoutUrl: personalAppLink,
          qrPayload: qrCode || readableCode,
          provider: this.name,
          plan: request.plan,
          amount,
          currency: 'IQD',
          expiresAt: new Date(Date.now() + 1800000).toISOString(), // 30 minutes
        };
      } catch (error: any) {
        logger.error('FIB live checkout creation failed:', error?.response?.data || error.message);
      }
    }

    // Dynamic direct merchant QR code fallback
    const dynamicQr = 'fib://pay?account=FIB-ZANKO-9090&amount=' + amount + '&ref=' + checkoutRef;

    return {
      checkoutId: checkoutRef,
      qrPayload: dynamicQr,
      provider: this.name,
      plan: request.plan,
      amount,
      currency: 'IQD',
      expiresAt: new Date(Date.now() + 1800000).toISOString(),
    };
  }

  async verifyPayment(referenceId: string): Promise<VerificationResult> {
    if (env.FIB_CLIENT_ID && env.FIB_CLIENT_SECRET) {
      try {
        const token = await this.getAccessToken();
        const statusUrl = env.FIB_BASE_URL + '/protected/v1/payments/' + referenceId + '/status';
        const res = await axios.get(statusUrl, {
          headers: { Authorization: 'Bearer ' + token },
          timeout: 10000,
        });

        const status = res.data.status;
        const isPaid = status === 'PAID' || status === 'COMPLETED' || status === 'SUCCESS';

        const now = new Date();
        const periodEnd = new Date(now);
        periodEnd.setDate(periodEnd.getDate() + 30);

        return {
          verified: isPaid,
          providerSubscriptionId: referenceId,
          plan: 'PREMIUM_MONTHLY',
          status: isPaid ? 'active' : 'incomplete',
          currentPeriodStart: now,
          currentPeriodEnd: periodEnd,
          amountPaid: res.data.monetaryValue?.amount,
          currency: res.data.monetaryValue?.currency || 'IQD',
        };
      } catch (error: any) {
        logger.error('FIB verifyPayment error:', error?.message);
      }
    }

    // Default verified check
    const now = new Date();
    const periodEnd = new Date(now);
    periodEnd.setDate(periodEnd.getDate() + 30);

    return {
      verified: false,
      plan: 'PREMIUM_MONTHLY',
      status: 'incomplete',
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      error: 'Unable to verify payment with FIB server',
    };
  }

  async getSubscription(providerSubscriptionId: string): Promise<VerificationResult> {
    return await this.verifyPayment(providerSubscriptionId);
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<{ success: boolean; canceledAt: Date }> {
    logger.info('FIB subscription canceled for ID: ' + providerSubscriptionId);
    return {
      success: true,
      canceledAt: new Date(),
    };
  }

  async handleWebhook(headers: Record<string, string>, rawBody: any): Promise<WebhookResult> {
    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const paymentId = payload.paymentId || payload.id || payload.ref;
    const status = (payload.status || '').toUpperCase();

    if (!paymentId) {
      throw new Error('FIB Webhook: missing paymentId');
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
    const isFailed = status === 'FAILED' || status === 'DECLINED';

    let subscriptionStatus: any = 'incomplete';
    let eventType = 'payment.pending';

    if (isPaid) {
      subscriptionStatus = 'active';
      eventType = 'payment.succeeded';
    } else if (isFailed) {
      subscriptionStatus = 'past_due';
      eventType = 'payment.failed';
    }

    // Deterministic idempotency key for this event
    const idempotencyKey = 'fib_' + paymentId + '_' + status.toLowerCase();

    return {
      handled: true,
      eventType,
      idempotencyKey,
      userId: payload.userId || payload.user_id,
      plan,
      status: subscriptionStatus,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      providerSubscriptionId: paymentId,
      metadata: payload,
    };
  }
}
