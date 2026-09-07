// ==============================================================================
// ZankoAI Payment Provider Interface Abstraction
// ==============================================================================

import {
  CheckoutRequest,
  CheckoutResult,
  VerificationResult,
  WebhookResult,
} from '../../types/subscription.types.js';

/**
 * Universal payment provider contract.
 * Any payment gateway (FIB, FastPay, ZainCash, Stripe, In-App Purchase)
 * plugs in here without altering core subscription business logic.
 */
export interface PaymentProvider {
  /**
   * Unique system identifier for this provider (e.g. 'fib', 'fastpay', 'zaincash', 'stripe')
   */
  readonly name: string;

  /**
   * Creates an authorized checkout session or payment order with the provider.
   */
  createCheckout(request: CheckoutRequest): Promise<CheckoutResult>;

  /**
   * Verifies a completed payment directly with the provider server.
   */
  verifyPayment(referenceId: string, payload?: any): Promise<VerificationResult>;

  /**
   * Fetches latest subscription state directly from the provider.
   */
  getSubscription(providerSubscriptionId: string): Promise<VerificationResult>;

  /**
   * Cancels a recurring subscription at the provider.
   */
  cancelSubscription(
    providerSubscriptionId: string
  ): Promise<{ success: boolean; canceledAt: Date }>;

  /**
   * Cryptographically validates and translates an inbound provider webhook payload.
   * Throws an error if signature is invalid or payload is forged.
   */
  handleWebhook(
    headers: Record<string, string>,
    rawBody: any
  ): Promise<WebhookResult>;
}
