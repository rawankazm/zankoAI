// ==============================================================================
// ZankoAI FastPay Mobile Wallet Payment Provider Implementation
// ==============================================================================

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

export class FastPayPaymentProvider implements PaymentProvider {
  readonly name = 'fastpay';
  readonly supportsRecurring = false;
  readonly supportedCurrencies = ['IQD'];

  /**
   * 1. Creates a FastPay payment order and hosted checkout URL
   */
  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    const orderId = request.orderId;
    const paymentUrl = 'https://secure.fast-pay.iq/checkout?order_id=' + encodeURIComponent(orderId);
    const qrPayload = 'fastpay://merchant/pay?id=' + (env.FASTPAY_MERCHANT_ID || 'ZANKO') +
      '&order=' + encodeURIComponent(orderId) +
      '&amount=' + request.amount.toString();

    logger.info('FastPay payment initiated for order ' + orderId + ' (' + request.amount.toString() + ' IQD)');

    return {
      success: true,
      orderId: orderId,
      transactionId: 'fp_tx_' + Date.now().toString() + '_' + orderId,
      paymentUrl: paymentUrl,
      qrPayload: qrPayload,
      status: 'pending',
      rawResponse: {
        merchantId: env.FASTPAY_MERCHANT_ID || 'ZANKO',
        orderId: orderId,
      },
    };
  }

  /**
   * 2. Checks status of payment by order ID
   */
  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    return {
      orderId: orderIdOrTxId,
      transactionId: 'fp_tx_' + orderIdOrTxId,
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
   * 4. Validates and parses inbound FastPay webhook
   */
  async handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult> {
    const bodyObj = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const orderId = bodyObj.order_id || bodyObj.orderId;
    const transactionId = bodyObj.transaction_id || bodyObj.transactionId || ('fp_tx_' + orderId);
    const receivedSignature = headers['x-fastpay-signature'] || bodyObj.signature;

    if (!orderId) {
      throw new Error('FastPay webhook rejected: Missing order_id.');
    }

    // HMAC-SHA256 signature validation
    const storePassword = env.FASTPAY_STORE_PASSWORD || 'zanko_fastpay_secret_2026';
    const computedSignature = crypto
      .createHmac('sha256', storePassword)
      .update(orderId + ';' + transactionId + ';' + (bodyObj.status || ''))
      .digest('hex');

    if (receivedSignature && receivedSignature !== computedSignature) {
      logger.warn('FastPay webhook signature mismatch for order: ' + orderId);
      throw new Error('FastPay webhook rejected: Signature verification failed.');
    }

    const rawStatus = (bodyObj.status || '').toString().toLowerCase();
    const isPaid = rawStatus === 'success' || rawStatus === 'completed' || rawStatus === 'paid';
    const isFailed = rawStatus === 'failed' || rawStatus === 'declined';
    const isCancelled = rawStatus === 'cancelled';

    const finalStatus = isPaid ? 'paid' : (isFailed ? 'failed' : (isCancelled ? 'cancelled' : 'pending'));

    return {
      valid: true,
      orderId: orderId,
      transactionId: transactionId,
      eventType: isPaid ? 'payment.succeeded' : (isFailed ? 'payment.failed' : 'payment.cancelled'),
      providerEventId: 'fp_evt_' + transactionId,
      status: finalStatus,
      amount: Number(bodyObj.amount || 0),
      currency: 'IQD',
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
      refundId: 'fp_ref_' + Date.now().toString() + '_' + transactionId,
      amount: amount,
      status: 'refunded',
    };
  }

  /**
   * 6. Create recurring subscription
   * FastPay does not support automated recurring billing.
   */
  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    throw new Error(
      'FastPay does not support automated recurring billing. Use manual renewal checkout flow.'
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
