// ==============================================================================
// ZankoAI Sandbox & Test-Mode Payment Gateway Provider
// ==============================================================================

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

export interface SandboxConfig {
  simulateFailure?: boolean;
  simulateWrongAmount?: boolean;
  simulateWrongCurrency?: boolean;
  requireValidSignature?: boolean;
  sandboxSecret?: string;
}

export class SandboxPaymentProvider implements PaymentProvider {
  readonly name = 'sandbox';
  readonly supportsRecurring = true;
  readonly supportedCurrencies = ['IQD', 'USD', 'EUR'];

  private config: SandboxConfig;
  private readonly transactions: Map<string, { status: string; amount: number; currency: string }> = new Map();

  constructor(config?: SandboxConfig) {
    this.config = {
      simulateFailure: false,
      simulateWrongAmount: false,
      simulateWrongCurrency: false,
      requireValidSignature: true,
      sandboxSecret: 'sandbox_secret_key_zanko',
      ...config,
    };
  }

  setSimulationConfig(config: Partial<SandboxConfig>): void {
    this.config = { ...this.config, ...config };
  }

  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    const txId = 'sbx_tx_' + Date.now().toString() + '_' + request.orderId;
    this.transactions.set(request.orderId, {
      status: this.config.simulateFailure ? 'failed' : 'pending',
      amount: request.amount,
      currency: request.currency,
    });

    const paymentUrl = 'https://sandbox.zankoai.com/pay/' + encodeURIComponent(request.orderId) +
      '?amount=' + request.amount.toString() +
      '&currency=' + request.currency;

    return {
      success: !this.config.simulateFailure,
      orderId: request.orderId,
      transactionId: txId,
      paymentUrl: paymentUrl,
      qrPayload: 'zanko://pay/sandbox/' + request.orderId,
      status: this.config.simulateFailure ? 'failed' : 'pending',
      rawResponse: { simulated: true, provider: 'sandbox' },
    };
  }

  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    const record = this.transactions.get(orderIdOrTxId);
    if (!record) {
      return {
        orderId: orderIdOrTxId,
        status: 'pending',
        currency: 'IQD',
      };
    }

    return {
      orderId: orderIdOrTxId,
      transactionId: 'sbx_tx_' + orderIdOrTxId,
      status: record.status as any,
      amount: record.amount,
      currency: record.currency as any,
      paidAt: record.status === 'paid' ? new Date() : undefined,
    };
  }

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

  async handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult> {
    const bodyObj = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const signature = headers['x-sandbox-signature'] || headers['x-signature'] || bodyObj?.signature;

    if (this.config.requireValidSignature) {
      if (!signature || signature === 'invalid_signature_mock') {
        throw new Error('Sandbox webhook rejected: Invalid cryptographic signature.');
      }
    }

    const orderId = bodyObj.orderId || bodyObj.order_id;
    if (!orderId) {
      throw new Error('Sandbox webhook rejected: Missing order ID.');
    }

    const rawStatus = (bodyObj.status || 'paid').toString().toLowerCase();
    const isPaid = rawStatus === 'paid' || rawStatus === 'success' || rawStatus === 'completed';
    const isFailed = rawStatus === 'failed';
    const isCancelled = rawStatus === 'cancelled';

    const finalStatus = isPaid ? 'paid' : (isFailed ? 'failed' : (isCancelled ? 'cancelled' : 'pending'));
    const txId = bodyObj.transactionId || bodyObj.transaction_id || ('sbx_tx_' + orderId);

    // Update internal simulated ledger
    this.transactions.set(orderId, {
      status: finalStatus,
      amount: Number(bodyObj.amount || 15000),
      currency: bodyObj.currency || 'IQD',
    });

    return {
      valid: true,
      orderId: orderId,
      transactionId: txId,
      eventType: isPaid ? 'payment.succeeded' : (isFailed ? 'payment.failed' : 'payment.cancelled'),
      providerEventId: bodyObj.eventId || ('sbx_evt_' + Date.now().toString() + '_' + orderId),
      status: finalStatus,
      amount: Number(bodyObj.amount || 15000),
      currency: bodyObj.currency || 'IQD',
      payload: bodyObj,
    };
  }

  async refundPayment(
    transactionId: string,
    amount?: number,
    reason?: string
  ): Promise<RefundResult> {
    return {
      success: true,
      refundId: 'sbx_ref_' + Date.now().toString() + '_' + transactionId,
      amount: amount,
      status: 'refunded',
    };
  }

  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    const subId = 'sbx_sub_' + Date.now().toString() + '_' + request.userId;
    const now = new Date();
    const end = new Date(now.getTime() + (request.interval === 'year' ? 365 : 30) * 86400000);

    return {
      success: true,
      providerSubscriptionId: subId,
      status: 'active',
      currentPeriodStart: now,
      currentPeriodEnd: end,
    };
  }

  async cancelSubscription(
    providerSubscriptionId: string
  ): Promise<CancelSubscriptionResult> {
    return {
      success: true,
      canceledAt: new Date(),
    };
  }
}
