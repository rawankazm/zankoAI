// ==============================================================================
// ZankoAI Payment Provider Interface Abstraction
// ==============================================================================

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

/**
 * Universal payment provider contract.
 * Any payment gateway (Qi Card, ZainCash, FastPay, FIB, Visa/Mastercard, Sandbox)
 * plugs in through this interface without changing subscription or business logic.
 */
export interface PaymentProvider {
  /**
   * Unique system identifier for this provider (e.g. 'qi_card', 'zaincash', 'fastpay', 'fib', 'sandbox')
   */
  readonly name: string;

  /**
   * Whether this provider supports automated recurring billing/subscriptions.
   * In Iraq, standard wallets and local gateways default to false (manual renewal).
   */
  readonly supportsRecurring: boolean;

  /**
   * List of supported ISO-4217 currencies (e.g. ['IQD', 'USD'])
   */
  readonly supportedCurrencies: string[];

  /**
   * 1. Creates a payment order / hosted checkout session with the provider.
   */
  createPayment(request: CreatePaymentRequest): Promise<PaymentResult>;

  /**
   * 2. Checks current status of a payment by order ID or provider transaction ID.
   */
  getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult>;

  /**
   * 3. Verifies a completed payment directly with the provider server.
   */
  verifyPayment(referenceId: string, payload?: any): Promise<VerificationResult>;

  /**
   * 4. Cryptographically validates and parses an inbound provider webhook payload.
   * Throws an error if the signature is invalid or payload is forged.
   */
  handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult>;

  /**
   * 5. Initiates a refund for a previously captured transaction.
   */
  refundPayment(
    transactionId: string,
    amount?: number,
    reason?: string
  ): Promise<RefundResult>;

  /**
   * 6. Creates a recurring subscription if supported by the provider.
   */
  createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult>;

  /**
   * 7. Cancels a recurring subscription at the provider.
   */
  cancelSubscription(
    providerSubscriptionId: string
  ): Promise<CancelSubscriptionResult>;
}
