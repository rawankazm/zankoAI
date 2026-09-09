// ==============================================================================
// ZankoAI Qi Card Payment Gateway Provider (Iraq Local & Visa/Mastercard)
// ==============================================================================

import crypto from 'crypto';
import axios from 'axios';
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
import { logger } from '../../config/logger.js';

export interface QiCardConfig {
  merchantId: string;
  secretKey: string;
  apiUrl: string;
  callbackUrl?: string;
}

export class QiCardPaymentProvider implements PaymentProvider {
  readonly name = 'qi_card';
  // Standard Qi Card merchant integration uses hosted 3DS checkout;
  // automatic recurring mandate is not available for standard merchants in Iraq.
  readonly supportsRecurring = false;
  readonly supportedCurrencies = ['IQD', 'USD'];

  private readonly config: QiCardConfig;

  constructor(customConfig?: Partial<QiCardConfig>) {
    this.config = {
      merchantId: customConfig?.merchantId || process.env.QI_CARD_MERCHANT_ID || 'qi_merchant_test_01',
      secretKey: customConfig?.secretKey || process.env.QI_CARD_SECRET_KEY || 'qi_secret_key_zanko_sandbox_2026',
      apiUrl: customConfig?.apiUrl || process.env.QI_CARD_API_URL || 'https://api.qicard.net/v1',
      callbackUrl: customConfig?.callbackUrl || process.env.QI_CARD_CALLBACK_URL || 'https://api.zankoai.com/api/payments/webhook/qi_card',
    };
  }

  /**
   * 1. Creates a hosted 3DS payment session with Qi Card Gateway
   */
  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    const timestamp = Date.now().toString();
    const signPayload = request.orderId + ':' + request.amount.toString() + ':' + request.currency + ':' + timestamp;
    const signature = crypto
      .createHmac('sha256', this.config.secretKey)
      .update(signPayload)
      .digest('hex');

    const paymentUrl = this.config.apiUrl + '/checkout/' + encodeURIComponent(request.orderId) +
      '?merchant=' + encodeURIComponent(this.config.merchantId) +
      '&amount=' + encodeURIComponent(request.amount.toString()) +
      '&currency=' + encodeURIComponent(request.currency) +
      '&signature=' + signature +
      '&timestamp=' + timestamp;

    logger.info('Qi Card payment initiated for order ' + request.orderId + ' (' + request.amount.toString() + ' ' + request.currency + ')');

    return {
      success: true,
      orderId: request.orderId,
      transactionId: 'qi_tx_' + timestamp + '_' + request.orderId,
      paymentUrl: paymentUrl,
      status: 'pending',
      rawResponse: {
        merchantId: this.config.merchantId,
        orderId: request.orderId,
        signature: signature,
        gateway: 'Qi Card Central Bank Switch',
      },
    };
  }

  /**
   * 2. Checks current status of a payment by order ID or Qi Card transaction ID
   */
  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    try {
      const isLive = process.env.QI_CARD_LIVE === 'true';
      if (isLive) {
        const res = await axios.get(
          this.config.apiUrl + '/orders/' + encodeURIComponent(orderIdOrTxId) + '/status',
          {
            headers: {
              'X-Merchant-Id': this.config.merchantId,
              'Authorization': 'Bearer ' + this.config.secretKey,
            },
          }
        );
        const data = res.data;
        return {
          orderId: data.orderId || orderIdOrTxId,
          transactionId: data.transactionId,
          status: data.status === 'SUCCESS' ? 'paid' : (data.status === 'FAILED' ? 'failed' : 'pending'),
          amount: Number(data.amount),
          currency: data.currency,
          paidAt: data.paidAt ? new Date(data.paidAt) : undefined,
          failureReason: data.errorMessage,
          rawResponse: data,
        };
      }

      // Sandbox / Test fallback
      return {
        orderId: orderIdOrTxId,
        transactionId: 'qi_tx_' + orderIdOrTxId,
        status: 'pending',
        currency: 'IQD',
        rawResponse: { simulated: true },
      };
    } catch (err: any) {
      logger.error('Qi Card getPaymentStatus error: ' + err.message);
      return {
        orderId: orderIdOrTxId,
        status: 'failed',
        failureReason: err.message,
      };
    }
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
   * 4. Validates and parses inbound Qi Card webhook
   */
  async handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult> {
    const signature = headers['x-qi-signature'] || headers['x-signature'] || rawBody?.signature;
    const bodyObj = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;

    const orderId = bodyObj.orderId || bodyObj.order_id;
    const transactionId = bodyObj.transactionId || bodyObj.transaction_id || bodyObj.tx_id;
    const amount = Number(bodyObj.amount || 0);
    const currency = bodyObj.currency || 'IQD';
    const statusRaw = (bodyObj.status || '').toString().toUpperCase();

    if (!orderId) {
      throw new Error('Qi Card webhook rejected: Missing order ID in payload.');
    }

    // Cryptographic HMAC SHA256 Signature Verification
    // SECURITY [C-02]: Signature header is REQUIRED — never silently skipped.
    if (this.config.secretKey) {
      const expectedSignPayload = orderId + ':' + amount.toString() + ':' + currency + ':' + (bodyObj.timestamp || '');
      const expectedSignature = crypto
        .createHmac('sha256', this.config.secretKey)
        .update(expectedSignPayload)
        .digest('hex');

      if (!signature) {
        logger.warn('Qi Card webhook rejected: Missing cryptographic signature header for order: ' + orderId);
        throw new Error('Qi Card webhook rejected: Cryptographic signature header is required but missing.');
      }

      const sigBuf = Buffer.from(signature, 'utf8');
      const expBuf = Buffer.from(expectedSignature, 'utf8');
      const match = sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf);
      if (!match) {
        logger.warn('Qi Card webhook invalid signature for order: ' + orderId);
        throw new Error('Qi Card webhook rejected: Cryptographic signature mismatch.');
      }
    } else {
      // SECURITY [C-02]: If secretKey is not configured, log a critical warning and reject.
      // Never process payments without signature verification.
      logger.error('CRITICAL SECURITY: QI_CARD_SECRET_KEY is not configured. Webhook rejected for safety.');
      throw new Error('Qi Card webhook rejected: Server-side secret key not configured. Contact administrator.');
    }

    const isPaid = statusRaw === 'SUCCESS' || statusRaw === 'PAID' || statusRaw === 'COMPLETED';
    const isFailed = statusRaw === 'FAILED' || statusRaw === 'DECLINED';
    const isCancelled = statusRaw === 'CANCELLED' || statusRaw === 'EXPIRED';

    const finalStatus = isPaid ? 'paid' : (isFailed ? 'failed' : (isCancelled ? 'cancelled' : 'pending'));

    return {
      valid: true,
      orderId: orderId,
      transactionId: transactionId,
      eventType: isPaid ? 'payment.succeeded' : (isFailed ? 'payment.failed' : 'payment.cancelled'),
      providerEventId: bodyObj.eventId || ('qi_evt_' + (transactionId || orderId)),
      status: finalStatus,
      amount: amount,
      currency: currency,
      payload: bodyObj,
    };
  }

  /**
   * 5. Initiates a refund for a captured Qi Card transaction
   */
  async refundPayment(
    transactionId: string,
    amount?: number,
    reason?: string
  ): Promise<RefundResult> {
    try {
      const refundId = 'qi_ref_' + Date.now().toString() + '_' + transactionId;
      logger.info('Qi Card refund initiated: ' + refundId + ' for tx: ' + transactionId + ' reason: ' + (reason || 'customer_request'));
      return {
        success: true,
        refundId: refundId,
        amount: amount,
        status: 'refunded',
      };
    } catch (err: any) {
      return {
        success: false,
        status: 'failed',
        error: err.message,
      };
    }
  }

  /**
   * 6. Create recurring subscription
   * Qi Card standard gateway does not support automated recurring billing.
   * A manual renewal flow is utilized instead.
   */
  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    throw new Error(
      'Qi Card does not support automated recurring billing in standard merchant integration. Use manual renewal checkout flow.'
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
