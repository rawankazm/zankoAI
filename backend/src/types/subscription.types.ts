// ==============================================================================
// ZankoAI Premium Subscription System Types & Contracts
// ==============================================================================

export type SubscriptionPlanType =
  | 'FREE'
  | 'PREMIUM_MONTHLY'
  | 'PREMIUM_YEARLY'
  | 'STUDENT'
  | 'UNIVERSITY'
  | 'TEAM';

export type SubscriptionStatusType =
  | 'trialing'
  | 'active'
  | 'past_due'
  | 'canceled'
  | 'expired'
  | 'incomplete';

export type PaymentProviderType =
  | 'fib'
  | 'fastpay'
  | 'zaincash'
  | 'stripe'
  | 'voucher';

export interface SubscriptionRecord {
  id: string;
  user_id: string;
  plan: SubscriptionPlanType;
  status: SubscriptionStatusType;
  provider: string;
  provider_customer_id?: string | null;
  provider_subscription_id?: string | null;
  current_period_start: string;
  current_period_end: string;
  cancel_at_period_end: boolean;
  created_at: string;
  updated_at: string;
}

export interface SubscriptionEventRecord {
  id: string;
  subscription_id?: string | null;
  user_id: string;
  event_type: string;
  provider: string;
  provider_event_id?: string | null;
  idempotency_key?: string | null;
  payload: Record<string, any>;
  created_at: string;
}

export interface CheckoutRequest {
  userId: string;
  userEmail?: string;
  plan: SubscriptionPlanType;
  returnUrl?: string;
  cancelUrl?: string;
  metadata?: Record<string, any>;
}

export interface CheckoutResult {
  checkoutId: string;
  checkoutUrl?: string;
  qrPayload?: string;
  provider: string;
  plan: SubscriptionPlanType;
  amount: number;
  currency: string;
  expiresAt?: string;
}

export interface VerificationResult {
  verified: boolean;
  providerSubscriptionId?: string;
  providerCustomerId?: string;
  plan: SubscriptionPlanType;
  status: SubscriptionStatusType;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  amountPaid?: number;
  currency?: string;
  error?: string;
}

export interface WebhookResult {
  handled: boolean;
  eventType: string;
  idempotencyKey: string;
  userId?: string;
  plan?: SubscriptionPlanType;
  status?: SubscriptionStatusType;
  currentPeriodStart?: Date;
  currentPeriodEnd?: Date;
  providerSubscriptionId?: string;
  providerCustomerId?: string;
  metadata?: Record<string, any>;
}

export interface SubscriptionStatusResponse {
  hasActiveSubscription: boolean;
  isPremium: boolean;
  plan: SubscriptionPlanType;
  status: SubscriptionStatusType;
  currentPeriodStart?: string;
  currentPeriodEnd?: string;
  cancelAtPeriodEnd: boolean;
  provider?: string;
  daysRemaining?: number;
}
