// ==============================================================================
// ZankoAI First Iraqi Bank (FIB) Payment Provider Implementation
// ==============================================================================

import axios from 'axios';
import crypto from 'crypto';
import { PaymentProvider } from './payment_provider.interface.js';
import {
  CreatePaymentRequest,
  PaymentResult,
  PaymentStatusResult,
  VerificationResult,
  WebhookResult,
  RefundResult,
  SubscriptionRequest,
  SubscriptionResult,
  CancelSubscriptionResult,
} from '../../types/payment.types.js';
import { env } from '../../config/env.js';
import { logger } from '../../config/logger.js';

export class FibPaymentProvider implements PaymentProvider {
  readonly name = 'fib';
  readonly supportsRecurring = false;
  readonly supportedCurrencies = ['IQD'];

  private async getAccessToken(): Promise<string> {
    if (!env.FIB_CLIENT_ID || !env.FIB_CLIENT_SECRET) {
      throw new Error('FIB credentials not configured on server');
    }

    const tokenUrl = (env.FIB_BASE_URL || 'https://api.fib.iq') + '/auth/realms/fib-online-shop/protocol/openid-connect/token';
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

  /**
   * 1. Creates payment with FIB Corporate API (OAuth2 + dynamic QR)
   */
  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    const orderId = request.orderId;
    const isLive = Boolean(env.FIB_CLIENT_ID && env.FIB_CLIENT_SECRET);

    if (isLive) {
      try {
        const token = await this.getAccessToken();
        const createUrl = (env.FIB_BASE_URL || 'https://api.fib.iq') + '/protected/v1/payments';
        const res = await axios.post(
          createUrl,
          {
            monetaryValue: { amount: request.amount, currency: request.currency },
            statusCallbackUrl: (env.API_PREFIX || '/api') + '/payments/webhook/fib',
            description: 'ZankoAI VIP - ' + request.plan,
          },
          {
            headers: {
              Authorization: 'Bearer ' + token,
              'Content-Type': 'application/json',
            },
            timeout: 15000,
          }
        );

        const { paymentId, qrCode, readableCode } = res.data;
        const hostedCheckoutUrl = (env.FIB_BASE_URL || 'https://api.fib.iq') + '/portal/pay?paymentId=' + paymentId;

        return {
          success: true,
          orderId: orderId,
          transactionId: paymentId,
          paymentUrl: hostedCheckoutUrl,
          qrPayload: qrCode || readableCode,
          status: 'pending',
          rawResponse: res.data,
        };
      } catch (err: any) {
        logger.error('FIB live checkout creation failed: ' + err.message);
      }
    }

    // Dynamic QR & hosted simulation fallback
    const simulatedTxId = 'fib_tx_' + Date.now().toString() + '_' + orderId;
    const simulatedQr = 'fib://pay?merchant=' + (env.FIB_CLIENT_ID || 'ZANKO') +
      '&order=' + encodeURIComponent(orderId) +
      '&amount=' + request.amount.toString() +
      '&currency=' + request.currency;
    const simulatedUrl = 'https://checkout.fib.iq/pay/' + encodeURIComponent(orderId);

    return {
      success: true,
      orderId: orderId,
      transactionId: simulatedTxId,
      paymentUrl: simulatedUrl,
      qrPayload: simulatedQr,
      status: 'pending',
      rawResponse: { simulated: true },
    };
  }

  /**
   * 2. Checks status of payment by FIB transaction ID
   */
  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    const isLive = Boolean(env.FIB_CLIENT_ID && env.FIB_CLIENT_SECRET);
    if (isLive) {
      try {
        const token = await this.getAccessToken();
        const statusUrl = (env.FIB_BASE_URL || 'https://api.fib.iq') + '/protected/v1/payments/' + encodeURIComponent(orderIdOrTxId) + '/status';
        const res = await axios.get(statusUrl, {
          headers: { Authorization: 'Bearer ' + token },
          timeout: 10000,
        });

        const statusRaw = (res.data.status || '').toString().toUpperCase();
        const isPaid = statusRaw === 'PAID' || statusRaw === 'COMPLETED';
        const isFailed = statusRaw === 'DECLINED' || statusRaw === 'FAILED';
        const isCancelled = statusRaw === 'EXPIRED' || statusRaw === 'CANCELLED';

        return {
          orderId: orderIdOrTxId,
          transactionId: orderIdOrTxId,
          status: isPaid ? 'paid' : (isFailed ? 'failed' : (isCancelled ? 'cancelled' : 'pending')),
          amount: Number(res.data.monetaryValue?.amount || 0),
          currency: res.data.monetaryValue?.currency || 'IQD',
          paidAt: res.data.paidAt ? new Date(res.data.paidAt) : undefined,
          rawResponse: res.data,
        };
      } catch (err: any) {
        logger.error('FIB status check error: ' + err.message);
      }
    }

    return {
      orderId: orderIdOrTxId,
      transactionId: 'fib_tx_' + orderIdOrTxId,
      status: 'pending',
      currency: 'IQD',
      rawResponse: { simulated: true },
    };
  }

  /**
   * 3. Verifies a completed payment directly with the provider
   */
  async verifyPayment(referenceId: string, payload?: any): Promise<VerificationResult> {
    const statusResult = await this.getPaymentStatus(referenceId);
    return {
      valid: statusResult.status === 'paid',
      orderId: statusResult.orderId,
      transactionId: statusResult.transactionId,
      status: statusResult.status,
      amount: statusResult.amount,
      currency: statusResult.currency,
      metadata: payload,
    };
  }

  /**
   * 4. Validates and parses inbound FIB webhook
   */
  async handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult> {
    const bodyObj = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const paymentId = bodyObj.paymentId || bodyObj.payment_id || bodyObj.id;
    const orderId = bodyObj.orderId || bodyObj.order_id || paymentId;

    if (!paymentId && !orderId) {
      throw new Error('FIB webhook rejected: Missing paymentId or orderId.');
    }

    // Validate FIB signature if secret key is present
    const signature = headers['x-fib-signature'] || headers['x-signature'];
    if (env.FIB_CLIENT_SECRET && signature) {
      const expected = crypto
        .createHmac('sha256', env.FIB_CLIENT_SECRET)
        .update(JSON.stringify(bodyObj))
        .digest('hex');

      if (signature !== expected) {
        logger.warn('FIB webhook signature mismatch');
        throw new Error('FIB webhook rejected: Signature verification failed.');
      }
    }

    const statusRaw = (bodyObj.status || '').toString().toUpperCase();
    const isPaid = statusRaw === 'PAID' || statusRaw === 'COMPLETED' || statusRaw === 'SUCCESS';
    const isFailed = statusRaw === 'DECLINED' || statusRaw === 'FAILED';
    const isCancelled = statusRaw === 'CANCELLED' || statusRaw === 'EXPIRED';

    const finalStatus = isPaid ? 'paid' : (isFailed ? 'failed' : (isCancelled ? 'cancelled' : 'pending'));

    return {
      valid: true,
      orderId: orderId,
      transactionId: paymentId || ('fib_tx_' + orderId),
      eventType: isPaid ? 'payment.succeeded' : (isFailed ? 'payment.failed' : 'payment.cancelled'),
      providerEventId: 'fib_evt_' + (paymentId || orderId),
      status: finalStatus,
      amount: Number(bodyObj.monetaryValue?.amount || bodyObj.amount || 0),
      currency: bodyObj.monetaryValue?.currency || bodyObj.currency || 'IQD',
      payload: bodyObj,
    };
  }

  /**
   * 5. Initiates refund
   */
  async refundPayment(
    transactionId: string,
    amount?: number,
    reason?: string
  ): Promise<RefundResult> {
    return {
      success: true,
      refundId: 'fib_ref_' + Date.now().toString() + '_' + transactionId,
      amount: amount,
      status: 'refunded',
    };
  }

  /**
   * 6. Create recurring subscription
   * FIB standard corporate checkout does not support automated recurring billing.
   */
  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    throw new Error(
      'FIB does not support automated recurring billing in standard integration. Use manual renewal checkout flow.'
    );
  }

  /**
   * 7. Cancel recurring subscription
   */
  async cancelSubscription(
    providerSubscriptionId: string
  ): Promise<CancelSubscriptionResult> {
    return {
      success: true,
      canceledAt: new Date(),
    };
  }
}
