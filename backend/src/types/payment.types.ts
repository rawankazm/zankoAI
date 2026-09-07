// ==============================================================================
// ZankoAI Payment Architecture Types & Domain Contracts
// ==============================================================================

export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'cancelled' | 'refunded';
export type PaymentCurrency = 'IQD' | 'USD' | 'EUR';

export interface PaymentRecord {
  id: string;
  user_id: string;
  provider: string;
  order_id: string;
  transaction_id: string | null;
  amount: number;
  currency: PaymentCurrency;
  status: PaymentStatus;
  plan: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface PaymentEventRecord {
  id: string;
  payment_id: string | null;
  provider: string;
  provider_event_id: string | null;
  event_type: string;
  idempotency_key: string | null;
  payload: Record<string, any>;
  created_at: string;
}

export interface CreatePaymentRequest {
  orderId: string;
  amount: number;
  currency: PaymentCurrency;
  plan: string;
  userId: string;
  description?: string;
  callbackUrl?: string;
  customerInfo?: {
    name?: string;
    email?: string;
    phone?: string;
  };
  metadata?: Record<string, any>;
}

export interface PaymentResult {
  success: boolean;
  orderId: string;
  transactionId?: string;
  paymentUrl?: string;
  qrPayload?: string;
  status: PaymentStatus;
  rawResponse?: any;
  errorMessage?: string;
}

export interface PaymentStatusResult {
  orderId: string;
  transactionId?: string;
  status: PaymentStatus;
  amount?: number;
  currency?: PaymentCurrency;
  paidAt?: Date;
  failureReason?: string;
  rawResponse?: any;
}

export interface VerificationResult {
  valid: boolean;
  orderId: string;
  transactionId?: string;
  status: PaymentStatus;
  amount?: number;
  currency?: PaymentCurrency;
  metadata?: Record<string, any>;
  error?: string;
}

export interface WebhookResult {
  valid: boolean;
  orderId: string;
  transactionId?: string;
  eventType: string;
  providerEventId?: string;
  status: PaymentStatus;
  amount?: number;
  currency?: PaymentCurrency;
  payload: any;
  errorMessage?: string;
}

export interface RefundResult {
  success: boolean;
  refundId?: string;
  amount?: number;
  status: 'refunded' | 'pending' | 'failed';
  error?: string;
}

export interface SubscriptionRequest {
  userId: string;
  plan: string;
  amount: number;
  currency: PaymentCurrency;
  interval: 'month' | 'year';
  customerInfo?: {
    name?: string;
    email?: string;
    phone?: string;
  };
}

export interface SubscriptionResult {
  success: boolean;
  providerSubscriptionId?: string;
  status: 'active' | 'trialing' | 'incomplete';
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  rawResponse?: any;
  error?: string;
}

export interface CancelSubscriptionResult {
  success: boolean;
  canceledAt: Date;
  error?: string;
}
