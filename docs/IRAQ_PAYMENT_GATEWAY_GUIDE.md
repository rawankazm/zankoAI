# ZankoAI Iraq Payment Gateway Architecture Guide

## Overview

The ZankoAI payment layer is designed as a **pluggable, decoupled payment gateway abstraction**. It enables ZankoAI to accept payments from multiple Iraqi local providers, regional mobile wallets, and international card networks without altering any core subscription, student, or learning business logic.

---

## Supported Payment Gateways

| Category | Provider | Technology & Protocol | Recurring Support |
|---|---|---|---|
| **Iraqi Local Gateway** | **Qi Card** | Central Bank switch, hosted 3DS checkout, HMAC-SHA256 webhooks | Manual Renewal |
| **Visa / Mastercard** | **Qi Card / Hosted 3DS** | Tokenized hosted checkout, 3D Secure 2.0 | Manual Renewal |
| **Mobile Wallet** | **ZainCash** | Signed JWT transaction tokens, redirect URL callback | Manual Renewal |
| **Mobile Wallet** | **FastPay** | Merchant order redirect, HMAC-SHA256 signature verification | Manual Renewal |
| **Mobile Wallet** | **First Iraqi Bank (FIB)** | Corporate OAuth2, dynamic QR codes, payment status webhooks | Manual Renewal |
| **Testing & CI/CD** | **Sandbox Provider** | In-memory ledger, configurable failure/signature simulation | Full Simulation |

---

## Core Security & PCI DSS Compliance Principles

1. **Zero Card Data Storage**:
   - ZankoAI servers **never** receive, process, or store raw Primary Account Numbers (PAN), CVVs, CVCs, PINs, or magnetic stripe data.
   - All card payments use hosted payment pages, 3D Secure redirect flows, or provider-hosted tokenized forms.

2. **Zero Client Trust Architecture**:
   - The Flutter mobile application is **never** trusted to assert payment success, amount, currency, or subscription state.
   - All payment orders are created by the backend server with an immutable order ID and amount in Iraqi Dinars (IQD).
   - VIP and Premium features are activated exclusively upon cryptographically verified server-to-server webhook callbacks or authenticated status polling.

3. **9-Point Inbound Webhook Verification**:
   Every incoming provider webhook undergoes 9 validation stages before altering database state:
   - **Step 1**: Cryptographic signature validation (HMAC-SHA256, JWT, or RSA).
   - **Step 2**: Provider event and transaction ID presence check.
   - **Step 3**: Database lookup matching `order_id`.
   - **Step 4**: Exact amount match verification (`payment.amount == webhook.amount`).
   - **Step 5**: Exact currency match verification (`payment.currency == webhook.currency`).
   - **Step 6**: Merchant/Account identifier match.
   - **Step 7**: Transaction terminal status validation (`paid`, `failed`, `cancelled`).
   - **Step 8**: Distributed idempotency deduplication via Redis and `payment_events`.
   - **Step 9**: Atomic, exactly-once subscription extension and VIP profile update.

---

## Recurring vs. Manual Renewal in Iraq

> [!NOTE]
> In the Iraqi banking and mobile wallet ecosystem, automatic recurring billing (tokenized auto-debit) is not standard for retail mobile merchants.
> 
> Therefore:
> - Each provider adapter declares `supportsRecurring: boolean`.
> - For Iraqi providers (`supportsRecurring = false`), a **secure manual renewal flow** is provided.
> - When a student's subscription approaches expiration, the mobile app prompts the user to renew.
> - Clicking "Renew" invokes `POST /api/payments/checkout` with `isRenewal: true`. Upon payment, the server extends `current_period_end` by another 30 or 365 days without duplicate subscriptions or state corruption.

---

## How to Add a New Payment Provider in 3 Steps

### Step 1: Implement the `PaymentProvider` Interface

Create a new adapter file in `backend/src/services/payment_providers/<provider_name>_payment_provider.ts`:

```typescript
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

export class CustomIraqPaymentProvider implements PaymentProvider {
  readonly name = 'custom_provider';
  readonly supportsRecurring = false;
  readonly supportedCurrencies = ['IQD', 'USD'];

  async createPayment(request: CreatePaymentRequest): Promise<PaymentResult> {
    // Call provider checkout endpoint, return hosted checkout URL or QR
    return {
      success: true,
      orderId: request.orderId,
      transactionId: 'tx_' + request.orderId,
      paymentUrl: 'https://gateway.example.iq/pay/' + request.orderId,
      status: 'pending',
    };
  }

  async getPaymentStatus(orderIdOrTxId: string): Promise<PaymentStatusResult> {
    // Query provider status endpoint
    return {
      orderId: orderIdOrTxId,
      status: 'paid',
      currency: 'IQD',
    };
  }

  async verifyPayment(referenceId: string, payload?: any): Promise<VerificationResult> {
    // Perform server-to-server verification
    return {
      valid: true,
      orderId: referenceId,
      status: 'paid',
    };
  }

  async handleWebhook(headers: Record<string, string>, rawBody: any): Promise<WebhookResult> {
    // 1. Verify HMAC or signature header
    // 2. Return parsed orderId, transactionId, status, amount, and currency
    return {
      valid: true,
      orderId: rawBody.orderId,
      transactionId: rawBody.transactionId,
      eventType: 'payment.succeeded',
      status: 'paid',
      amount: Number(rawBody.amount),
      currency: rawBody.currency,
      payload: rawBody,
    };
  }

  async refundPayment(transactionId: string, amount?: number, reason?: string): Promise<RefundResult> {
    return { success: true, status: 'refunded' };
  }

  async createSubscription(request: SubscriptionRequest): Promise<SubscriptionResult> {
    throw new Error('Automated recurring billing not supported. Use manual renewal flow.');
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<CancelSubscriptionResult> {
    return { success: true, canceledAt: new Date() };
  }
}
```

### Step 2: Register in `PaymentProviderRegistry`

Open `backend/src/services/payment_providers/index.ts` and add the provider instance:

```typescript
import { CustomIraqPaymentProvider } from './custom_iraq_payment_provider.js';

PaymentProviderRegistry.register(new CustomIraqPaymentProvider());
```

### Step 3: Configure Environment Variables

Add provider credentials in `.env`:

```bash
PAYMENT_DEFAULT_PROVIDER=custom_provider
CUSTOM_PROVIDER_MERCHANT_ID=your_merchant_id
CUSTOM_PROVIDER_SECRET_KEY=your_secret_key
CUSTOM_PROVIDER_API_URL=https://api.customgateway.iq
```

Done! The `/api/payments/checkout` and `/api/payments/webhook/custom_provider` endpoints now automatically support the new payment gateway.

---

## Sandbox / Test Mode Configuration

To test payments locally or in automated testing environments without live bank credentials:

1. In `.env`:
   ```bash
   PAYMENT_DEFAULT_PROVIDER=sandbox
   PAYMENT_SANDBOX_MODE=true
   ```

2. When `PAYMENT_SANDBOX_MODE=true`, all payments utilize `SandboxPaymentProvider`, returning simulated checkout URLs and instant webhooks.
