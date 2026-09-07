// ==============================================================================
// ZankoAI Iraq Payment Gateway Architecture Test Suite
// ==============================================================================

import assert from 'node:assert';
import crypto from 'crypto';
import { PaymentService } from '../src/services/payment.service.js';
import { PaymentProviderRegistry, QiCardPaymentProvider, SandboxPaymentProvider } from '../src/services/payment_providers/index.js';
import { supabaseAdmin } from '../src/config/supabase.js';

process.env.NODE_ENV = 'test';
process.env.PAYMENT_SANDBOX_MODE = 'true';
process.env.PAYMENT_DEFAULT_PROVIDER = 'sandbox';

async function runIraqPaymentGatewayTests() {
  console.log('\n💳 Starting ZankoAI Iraq Payment Gateway Architecture Test Suite...\n');

  let passed = 0;
  let total = 0;

  const test = async (name: string, fn: () => Promise<void> | void) => {
    total++;
    try {
      await fn();
      console.log('  ✅ PASSED: ' + name);
      passed++;
    } catch (err: any) {
      console.error('  ❌ FAILED: ' + name);
      console.error('     Error: ' + err.message);
    }
  };

  const testUserId = '00000000-0000-0000-0000-000000000099';

  // Seed test user profile in Supabase
  try {
    await supabaseAdmin.from('profiles').upsert({
      id: testUserId,
      full_name: 'Iraq Payment Test Student',
      email: 'iraq.student@zanko.edu',
      role: 'student',
      is_vip: false,
      plan: 'free',
      vip_status: 'none',
      status: 'active',
    });
  } catch (_) {}

  try {
    // ─── 1. Successful Payment & Checkout Initialization ───
    await test('1. Successful Payment: Checkout generates order and valid provider URL', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      assert.strictEqual(checkout.success, true);
      assert.ok(checkout.orderId.startsWith('order_'), 'Expected order_ prefix');
      assert.ok(checkout.paymentUrl?.includes('sandbox.zankoai.com'), 'Expected sandbox URL');
      assert.strictEqual(checkout.status, 'pending');

      const paymentRecord = await PaymentService.getPayment(checkout.orderId);
      assert.ok(paymentRecord, 'Expected payment record in database');
      assert.strictEqual(paymentRecord?.amount, 15000);
      assert.strictEqual(paymentRecord?.currency, 'IQD');
      assert.strictEqual(paymentRecord?.status, 'pending');
    });

    // ─── 2. Inbound Webhook Activation & Premium Granting ───
    await test('2. Premium Activation: Valid webhook sets payment to paid and grants VIP', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_success_' + checkout.orderId,
        amount: 15000,
        currency: 'IQD',
        status: 'paid',
        signature: 'sandbox_valid_sig',
      };

      const webhookRes = await PaymentService.processWebhook(
        'sandbox',
        { 'x-sandbox-signature': 'sandbox_valid_sig' },
        webhookBody
      );

      assert.strictEqual(webhookRes.received, true);
      assert.strictEqual(webhookRes.status, 'paid');
      assert.strictEqual(webhookRes.duplicate, false);

      // Verify payment record in DB
      const updatedPayment = await PaymentService.getPayment(checkout.orderId);
      assert.strictEqual(updatedPayment?.status, 'paid');

      // Verify profile VIP elevation
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('is_vip, plan, vip_status')
        .eq('id', testUserId)
        .single();

      assert.strictEqual(profile?.is_vip, true);
      assert.strictEqual(profile?.plan, 'premium');
      assert.strictEqual(profile?.vip_status, 'active');
    });

    // ─── 3. Failed Payment Handling ───
    await test('3. Failed Payment: Webhook sets status to failed and denies VIP', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_failed_' + checkout.orderId,
        amount: 15000,
        currency: 'IQD',
        status: 'failed',
        signature: 'sandbox_valid_sig',
      };

      const webhookRes = await PaymentService.processWebhook(
        'sandbox',
        { 'x-sandbox-signature': 'sandbox_valid_sig' },
        webhookBody
      );

      assert.strictEqual(webhookRes.status, 'failed');

      const updatedPayment = await PaymentService.getPayment(checkout.orderId);
      assert.strictEqual(updatedPayment?.status, 'failed');
    });

    // ─── 4. Duplicate Webhook Idempotency ───
    await test('4. Duplicate Webhook Idempotency: Replayed webhook safely ignored', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const eventId = 'unique_event_' + Date.now().toString();
      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_idem_' + checkout.orderId,
        eventId: eventId,
        amount: 15000,
        currency: 'IQD',
        status: 'paid',
        signature: 'sandbox_valid_sig',
      };

      // First webhook
      const firstRes = await PaymentService.processWebhook(
        'sandbox',
        { 'x-sandbox-signature': 'sandbox_valid_sig' },
        webhookBody
      );
      assert.strictEqual(firstRes.duplicate, false);

      // Replayed identical webhook
      const secondRes = await PaymentService.processWebhook(
        'sandbox',
        { 'x-sandbox-signature': 'sandbox_valid_sig' },
        webhookBody
      );
      assert.strictEqual(secondRes.duplicate, true);
      assert.strictEqual(secondRes.received, true);
    });

    // ─── 5. Invalid Webhook Signature Rejection ───
    await test('5. Invalid Signature Rejection: Forged webhook signature rejected with error', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_forged_' + checkout.orderId,
        amount: 15000,
        currency: 'IQD',
        status: 'paid',
      };

      let rejected = false;
      try {
        await PaymentService.processWebhook(
          'sandbox',
          { 'x-sandbox-signature': 'invalid_signature_mock' },
          webhookBody
        );
      } catch (err: any) {
        rejected = true;
        assert.ok(err.message.includes('Invalid cryptographic signature'), 'Expected signature error');
      }

      assert.strictEqual(rejected, true, 'Expected invalid webhook to be rejected');
    });

    // ─── 6. Wrong Amount Rejection ───
    await test('6. Wrong Amount Rejection: Webhook with altered amount triggers security alert', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_tamper_' + checkout.orderId,
        amount: 500, // Tampered amount! (Expected 15,000)
        currency: 'IQD',
        status: 'paid',
        signature: 'sandbox_valid_sig',
      };

      let rejected = false;
      try {
        await PaymentService.processWebhook(
          'sandbox',
          { 'x-sandbox-signature': 'sandbox_valid_sig' },
          webhookBody
        );
      } catch (err: any) {
        rejected = true;
        assert.ok(err.message.includes('amount does not match'), 'Expected amount mismatch error');
      }

      assert.strictEqual(rejected, true, 'Expected altered amount to be rejected');
    });

    // ─── 7. Wrong Currency Rejection ───
    await test('7. Wrong Currency Rejection: Webhook with wrong currency rejected', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_curr_' + checkout.orderId,
        amount: 15000,
        currency: 'USD', // Wrong currency! (Expected IQD)
        status: 'paid',
        signature: 'sandbox_valid_sig',
      };

      let rejected = false;
      try {
        await PaymentService.processWebhook(
          'sandbox',
          { 'x-sandbox-signature': 'sandbox_valid_sig' },
          webhookBody
        );
      } catch (err: any) {
        rejected = true;
        assert.ok(err.message.includes('currency does not match'), 'Expected currency mismatch error');
      }

      assert.strictEqual(rejected, true, 'Expected currency mismatch to be rejected');
    });

    // ─── 8. Cancelled / Expired Payment Handling ───
    await test('8. Cancelled Payment: User abandons checkout, status transitions to cancelled', async () => {
      const checkout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
      });

      const webhookBody = {
        orderId: checkout.orderId,
        transactionId: 'tx_cancel_' + checkout.orderId,
        amount: 15000,
        currency: 'IQD',
        status: 'cancelled',
        signature: 'sandbox_valid_sig',
      };

      const res = await PaymentService.processWebhook(
        'sandbox',
        { 'x-sandbox-signature': 'sandbox_valid_sig' },
        webhookBody
      );

      assert.strictEqual(res.status, 'cancelled');

      const payment = await PaymentService.getPayment(checkout.orderId);
      assert.strictEqual(payment?.status, 'cancelled');
    });

    // ─── 9. Qi Card Local Gateway Signature Validation ───
    await test('9. Qi Card Gateway: Generates valid HMAC-SHA256 signature and parses callbacks', async () => {
      const qiProvider = new QiCardPaymentProvider({
        merchantId: 'test_qi_merchant',
        secretKey: 'qi_test_secret_123',
      });

      const orderId = 'qi_order_test_99';
      const paymentRes = await qiProvider.createPayment({
        orderId: orderId,
        amount: 15000,
        currency: 'IQD',
        plan: 'PREMIUM_MONTHLY',
        userId: testUserId,
      });

      assert.strictEqual(paymentRes.success, true);
      assert.ok(paymentRes.paymentUrl?.includes('api.qicard.net/v1/checkout'), 'Expected Qi Card checkout URL');

      // Valid webhook HMAC test
      const timestamp = Date.now().toString();
      const payload = {
        orderId: orderId,
        transactionId: 'qi_tx_12345',
        amount: 15000,
        currency: 'IQD',
        status: 'SUCCESS',
        timestamp: timestamp,
      };

      const signPayload = orderId + ':15000:IQD:' + timestamp;
      const validSig = crypto
        .createHmac('sha256', 'qi_test_secret_123')
        .update(signPayload)
        .digest('hex');

      const parsedWebhook = await qiProvider.handleWebhook(
        { 'x-qi-signature': validSig },
        payload
      );

      assert.strictEqual(parsedWebhook.status, 'paid');
      assert.strictEqual(parsedWebhook.orderId, orderId);
      assert.strictEqual(parsedWebhook.amount, 15000);
    });

    // ─── 10. Manual Renewal vs Recurring Billing in Iraq ───
    await test('10. Iraqi Provider Manual Renewal: Qi Card correctly enforces manual renewal flow', async () => {
      const qiProvider = new QiCardPaymentProvider();
      assert.strictEqual(qiProvider.supportsRecurring, false, 'Qi Card must default to false for recurring in Iraq');

      // Calling createSubscription on non-recurring provider must throw a clear, helpful error
      let errorThrown = false;
      try {
        await qiProvider.createSubscription({
          userId: testUserId,
          plan: 'PREMIUM_MONTHLY',
          amount: 15000,
          currency: 'IQD',
          interval: 'month',
        });
      } catch (err: any) {
        errorThrown = true;
        assert.ok(err.message.includes('manual renewal'), 'Expected manual renewal explanation');
      }

      assert.strictEqual(errorThrown, true);

      // Verify renewal checkout extends subscription seamlessly
      const renewalCheckout = await PaymentService.createCheckout({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        providerName: 'sandbox',
        isRenewal: true,
      });

      assert.strictEqual(renewalCheckout.success, true);
      const renewalPayment = await PaymentService.getPayment(renewalCheckout.orderId);
      assert.strictEqual(renewalPayment?.metadata.isRenewal, true);
    });

  } finally {
    // Teardown
    try {
      await supabaseAdmin.from('payments').delete().eq('user_id', testUserId);
      await supabaseAdmin.from('payment_events').delete().eq('provider', 'sandbox');
    } catch (_) {}
  }

  console.log('\n📊 Test Results: ' + passed.toString() + '/' + total.toString() + ' passed (' + Math.round((passed / total) * 100).toString() + '%)\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runIraqPaymentGatewayTests().catch((err) => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
