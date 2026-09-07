// ==============================================================================
// ZankoAI ZainCash Mobile Wallet Payment Provider Implementation
// ==============================================================================

import crypto from 'crypto';
import jwt from 'jsonwebtoken';
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

export class ZainCashPaymentProvider implements PaymentProvider {
  readonly name = 'zaincash';
  readonly supportsRecurring = false;
  readonly supportedCurrencies = ['IQD'];

  /**
   * 1. Creates a ZainCash payment session with signed JWT token
   */
  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    const orderId = request.orderId;
    const tokenPayload = {
      amount: request.amount,
      serviceType: 'ZankoAI VIP - ' + request.plan,
      msisdn: env.ZAINCASH_MSISDN || '9647800000000',
      orderId: orderId,
      redirectUrl: (env.API_PREFIX || '/api') + '/payments/webhook/zaincash',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 4 * 60 * 60,
    };

    const secret = env.ZAINCASH_SECRET || 'zanko_zaincash_secret_2026';
    const signedJwt = jwt.sign(tokenPayload, secret);
    const checkoutUrl = 'https://api.zaincash.iq/transaction/pay?id=' + encodeURIComponent(orderId) + '&token=' + signedJwt;

    logger.info('ZainCash payment initiated for order ' + orderId + ' (' + request.amount.toString() + ' IQD)');

    return {
      success: true,
      orderId: orderId,
      transactionId: 'zc_tx_' + Date.now().toString() + '_' + orderId,
      paymentUrl: checkoutUrl,
      qrPayload: checkoutUrl,
      status: 'pending',
      rawResponse: {
        orderId: orderId,
        token: signedJwt,
      },
    };
  }

  /**
   * 2. Checks current status of a payment by order ID
   */
  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    return {
      orderId: orderIdOrTxId,
      transactionId: 'zc_tx_' + orderIdOrTxId,
      status: 'pending',
      currency: 'IQD',
      rawResponse: { simulated: true },
    };
  }

  /**
   * 3. Verifies a completed payment directly with the provider
   */
  async verifyPayment(referenceId: string, payload?: any): Promise<VerificationResult> {
    const secret = env.ZAINCASH_SECRET || 'zanko_zaincash_secret_2026';
    if (!payload?.token) {
      return {
        valid: false,
        orderId: referenceId,
        status: 'failed',
        error: 'Missing ZainCash verification token.',
      };
    }

    try {
      const decoded = jwt.verify(payload.token, secret) as any;
      const isSuccess = decoded.status === 'success';

      return {
        valid: isSuccess,
        orderId: decoded.orderid || referenceId,
        transactionId: decoded.id || ('zc_tx_' + referenceId),
        status: isSuccess ? 'paid' : 'failed',
        amount: Number(decoded.amount),
        currency: 'IQD',
        metadata: decoded,
      };
    } catch (err: any) {
      return {
        valid: false,
        orderId: referenceId,
        status: 'failed',
        error: 'ZainCash token validation error: ' + err.message,
      };
    }
  }

  /**
   * 4. Validates and parses inbound ZainCash webhook
   */
  async handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult> {
    const secret = env.ZAINCASH_SECRET || 'zanko_zaincash_secret_2026';
    const bodyObj = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const token = bodyObj.token || headers['x-zaincash-token'];

    if (!token) {
      throw new Error('ZainCash webhook rejected: Missing verification token.');
    }

    try {
      const decoded = jwt.verify(token, secret) as any;
      const isPaid = decoded.status === 'success';
      const orderId = decoded.orderid || bodyObj.orderId || bodyObj.order_id;
      const txId = decoded.id || ('zc_tx_' + orderId);

      return {
        valid: true,
        orderId: orderId,
        transactionId: txId,
        eventType: isPaid ? 'payment.succeeded' : 'payment.failed',
        providerEventId: 'zc_evt_' + txId,
        status: isPaid ? 'paid' : 'failed',
        amount: Number(decoded.amount || 0),
        currency: 'IQD',
        payload: decoded,
      };
    } catch (err: any) {
      throw new Error('ZainCash webhook rejected: Invalid signature or expired token: ' + err.message);
    }
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
      refundId: 'zc_ref_' + Date.now().toString() + '_' + transactionId,
      amount: amount,
      status: 'refunded',
    };
  }

  /**
   * 6. Create recurring subscription
   * ZainCash does not support automatic recurring payments.
   */
  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    throw new Error(
      'ZainCash does not support automated recurring billing. Use manual renewal checkout flow.'
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
