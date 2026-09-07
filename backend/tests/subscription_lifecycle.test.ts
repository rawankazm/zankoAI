// ==============================================================================
// ZankoAI Premium Subscription Lifecycle & Maintenance Test Suite
// ==============================================================================

import assert from 'node:assert';
import { supabaseAdmin } from '../src/config/supabase.js';
import { SubscriptionService } from '../src/services/subscription.service.js';
import { processSubscriptionMaintenanceJob } from '../src/jobs/subscription_maintenance.js';

process.env.NODE_ENV = 'test';
process.env.PAYMENT_SANDBOX_MODE = 'true';
process.env.PAYMENT_DEFAULT_PROVIDER = 'sandbox';

async function runSubscriptionLifecycleTests() {
  console.log('\n👑 Starting ZankoAI Premium Lifecycle Architecture Test Suite...\n');

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
      if (err.stack) {
        console.error('     Stack: ' + err.stack);
      }
    }
  };

  const testUserId = '00000000-0000-0000-0000-000000000088';

  // Seed test user profile in Supabase
  try {
    await supabaseAdmin.from('profiles').upsert({
      id: testUserId,
      full_name: 'Lifecycle Test Student',
      email: 'lifecycle.student@zanko.edu',
      role: 'student',
      is_vip: false,
      plan: 'free',
      vip_status: 'none',
      status: 'active',
    });
  } catch (_) {}

  try {
    // ─── 1. Activation State ────────────────────────────────────────────────
    await test('1. Activation: Grants active status, VIP profile, and records event', async () => {
      const activated = await SubscriptionService.activateSubscription({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        provider: 'sandbox',
        durationDays: 30,
        autoRenew: false,
        metadata: { channel: 'test_activation' },
      });

      assert.strictEqual(activated.status, 'active');
      assert.strictEqual(activated.plan, 'PREMIUM_MONTHLY');
      assert.strictEqual(activated.cancel_at_period_end, false);

      const status = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(status.hasActiveSubscription, true);
      assert.strictEqual(status.isPremium, true);
      assert.strictEqual(status.status, 'active');
      assert.strictEqual(status.cancelAtPeriodEnd, false);
      assert.ok(status.daysRemaining && status.daysRemaining > 0, 'Expected positive daysRemaining');

      // Check profiles VIP elevation
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('is_vip, plan, vip_status')
        .eq('id', testUserId)
        .single();

      assert.strictEqual(profile?.is_vip, true);
      assert.strictEqual(profile?.plan, 'premium');
      assert.strictEqual(profile?.vip_status, 'active');

      // Check event history
      const { data: events } = await supabaseAdmin
        .from('subscription_events')
        .select('*')
        .eq('user_id', testUserId)
        .eq('event_type', 'subscription.activated');

      assert.ok(events && events.length > 0, 'Expected subscription.activated event');
    });

    // ─── 2. Renewal State ───────────────────────────────────────────────────
    await test('2. Renewal: Extends subscription seamlessly without losing remaining days', async () => {
      // Current active sub has ~30 days left
      const initialStatus = await SubscriptionService.getSubscription(testUserId);
      const initialEnd = new Date(initialStatus.currentPeriodEnd!).getTime();

      // Renew for 30 more days
      const renewed = await SubscriptionService.renewSubscription({
        userId: testUserId,
        durationDays: 30,
        provider: 'sandbox',
      });

      assert.strictEqual(renewed.status, 'active');
      const renewedEnd = new Date(renewed.current_period_end).getTime();

      // Expected new end is initialEnd + 30 days
      const expectedEnd = initialEnd + (30 * 86400000);
      const diffMs = Math.abs(renewedEnd - expectedEnd);
      assert.ok(diffMs < 5000, 'Renewal must append 30 days to existing period end without gap');

      const updatedStatus = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(updatedStatus.isPremium, true);
      assert.strictEqual(updatedStatus.status, 'active');

      // Check event history
      const { data: events } = await supabaseAdmin
        .from('subscription_events')
        .select('*')
        .eq('user_id', testUserId)
        .eq('event_type', 'subscription.renewed');

      assert.ok(events && events.length > 0, 'Expected subscription.renewed event');
    });

    // ─── 3. Cancellation (Cancel at Period End & Immediate) ─────────────────
    await test('3. Cancellation: Cancel at period end retains active benefits until expiry', async () => {
      const cancelRes = await SubscriptionService.cancelSubscription(testUserId, { immediate: false });
      assert.strictEqual(cancelRes.success, true);
      assert.strictEqual(cancelRes.status, 'active');

      const status = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(status.cancelAtPeriodEnd, true);
      assert.strictEqual(status.isPremium, true, 'User remains premium until period end');
      assert.strictEqual(status.status, 'active');

      // Immediate cancellation drops benefits immediately
      const immediateRes = await SubscriptionService.cancelSubscription(testUserId, { immediate: true });
      assert.strictEqual(immediateRes.success, true);
      assert.strictEqual(immediateRes.status, 'canceled');

      const immediateStatus = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(immediateStatus.isPremium, false);
      assert.strictEqual(immediateStatus.status, 'canceled');

      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('is_vip, vip_status')
        .eq('id', testUserId)
        .single();
      assert.strictEqual(profile?.is_vip, false);
      assert.strictEqual(profile?.vip_status, 'canceled');
    });

    // ─── 4. Failed Renewal & Grace Period (past_due) ────────────────────────
    await test('4. Failed Renewal & Grace Period: Transitions to past_due and tracks grace deadline', async () => {
      const pastDueSub = await SubscriptionService.handleFailedRenewal({
        userId: testUserId,
        reason: 'insufficient_funds',
        gracePeriodDays: 3,
      });

      assert.ok(pastDueSub, 'Expected updated subscription record');
      assert.strictEqual(pastDueSub?.status, 'past_due');
      assert.ok(pastDueSub?.grace_period_end, 'Expected grace_period_end timestamp');

      const status = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(status.status, 'past_due');
      assert.strictEqual(status.inGracePeriod, true);
      assert.ok(status.gracePeriodEnd, 'Expected gracePeriodEnd');

      // Verify event logged
      const { data: events } = await supabaseAdmin
        .from('subscription_events')
        .select('*')
        .eq('user_id', testUserId)
        .eq('event_type', 'subscription.renewal_failed');

      assert.ok(events && events.length > 0, 'Expected subscription.renewal_failed event');
    });

    // ─── 5. Strict Expiration Rule (current_period_end < now) ───────────────
    await test('5. Expiration: If current_period_end < now, user cannot be treated as Premium', async () => {
      // Set current_period_end in the past and grace period exhausted
      const pastDate = new Date(Date.now() - 5 * 86400000).toISOString();
      await supabaseAdmin
        .from('subscriptions')
        .update({
          status: 'active',
          current_period_end: pastDate,
          grace_period_end: pastDate,
          cancel_at_period_end: true,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', testUserId);

      // Call getSubscription
      const status = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(status.isPremium, false, 'STRICT RULE: isPremium must be false when current_period_end < now');
      assert.strictEqual(status.hasActiveSubscription, false);
      assert.strictEqual(status.status, 'expired');
      assert.strictEqual(status.daysRemaining, 0);

      // Verify profile is downgraded
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('is_vip, plan, vip_status')
        .eq('id', testUserId)
        .single();

      assert.strictEqual(profile?.is_vip, false);
      assert.strictEqual(profile?.plan, 'free');
      assert.strictEqual(profile?.vip_status, 'expired');

      // Verify subscription.expired event logged
      const { data: events } = await supabaseAdmin
        .from('subscription_events')
        .select('*')
        .eq('user_id', testUserId)
        .eq('event_type', 'subscription.expired');

      assert.ok(events && events.length > 0, 'Expected subscription.expired event');
    });

    // ─── 6. Scheduled Worker (subscription-maintenance) ─────────────────────
    await test('6. Scheduled Worker: Detects expired subscriptions, past due transitions, and reminders', async () => {
      // Seed a test subscription that is active but expired
      const pastDate = new Date(Date.now() - 2 * 86400000).toISOString();
      await supabaseAdmin
        .from('subscriptions')
        .update({
          status: 'active',
          current_period_end: pastDate,
          cancel_at_period_end: true,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', testUserId);

      const result = await processSubscriptionMaintenanceJob({
        triggeredBy: 'unit_test',
      });

      assert.ok(result.scannedCount >= 1, 'Expected at least 1 scanned subscription');
      assert.ok(result.expiredCount >= 1, 'Expected expiredCount >= 1');
      assert.ok(result.timestamp, 'Expected timestamp');

      // Verify user subscription is marked expired
      const sub = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(sub.status, 'expired');
      assert.strictEqual(sub.isPremium, false);
    });

    // ─── 7. History Endpoint (GET /api/subscription/history) ────────────────
    await test('7. History Endpoint: Aggregates subscription, payment, and event history', async () => {
      // Seed a payment record for user
      await supabaseAdmin.from('payments').insert({
        user_id: testUserId,
        provider: 'sandbox',
        order_id: 'order_hist_test_' + Date.now(),
        transaction_id: 'tx_hist_test_' + Date.now(),
        amount: 15000,
        currency: 'IQD',
        status: 'paid',
        plan: 'PREMIUM_MONTHLY',
        metadata: { channel: 'test' },
      });

      const history = await SubscriptionService.getSubscriptionHistory(testUserId);

      assert.ok(Array.isArray(history.subscriptions), 'Expected subscriptions array');
      assert.ok(Array.isArray(history.payments), 'Expected payments array');
      assert.ok(Array.isArray(history.events), 'Expected events array');

      assert.ok(history.subscriptions.length > 0, 'Expected at least one subscription');
      assert.ok(history.payments.length > 0, 'Expected at least one payment record');
      assert.ok(history.events.length > 0, 'Expected at least one event record');

      // Check event types recorded during lifecycle
      const eventTypes = history.events.map((e) => e.event_type);
      assert.ok(eventTypes.includes('subscription.activated'), 'Expected activated event in history');
      assert.ok(eventTypes.includes('subscription.renewed'), 'Expected renewed event in history');
      assert.ok(eventTypes.includes('subscription.expired'), 'Expected expired event in history');
    });

    // ─── 8. Auto-charge Protection Rule ─────────────────────────────────────
    await test('8. Auto-Charge Protection: Non-recurring providers and unauthorized users are not charged automatically', async () => {
      // Provider without recurring support or auto_renew = false
      const sub = await SubscriptionService.activateSubscription({
        userId: testUserId,
        plan: 'PREMIUM_MONTHLY',
        provider: 'qi_card', // Qi Card does not support auto-charge
        durationDays: 30,
        autoRenew: false, // User has NOT authorized recurring billing
      });

      assert.strictEqual(sub.auto_renew, false);

      // Force period end into past to test worker behavior
      const pastDate = new Date(Date.now() - 1000).toISOString();
      await supabaseAdmin
        .from('subscriptions')
        .update({
          current_period_end: pastDate,
          cancel_at_period_end: false,
          auto_renew: false,
        })
        .eq('id', sub.id);

      // Run maintenance worker
      const res = await SubscriptionService.runMaintenance();
      assert.ok(res.scannedCount >= 1);

      // Sub should enter past_due grace period, NOT charge automatically
      const current = await SubscriptionService.getSubscription(testUserId);
      assert.strictEqual(current.status, 'past_due');
      assert.strictEqual(current.inGracePeriod, true);
      assert.strictEqual(current.isPremium, false, 'Expired sub cannot be treated as Premium');
    });

  } finally {
    // Cleanup test user
    try {
      await supabaseAdmin.from('subscription_events').delete().eq('user_id', testUserId);
      await supabaseAdmin.from('subscriptions').delete().eq('user_id', testUserId);
      await supabaseAdmin.from('payments').delete().eq('user_id', testUserId);
      await supabaseAdmin.from('profiles').delete().eq('id', testUserId);
    } catch (_) {}
  }

  console.log('\n────────────────────────────────────────────────────────────────');
  console.log('Test Summary: ' + passed + '/' + total + ' tests passed.');
  console.log('────────────────────────────────────────────────────────────────\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runSubscriptionLifecycleTests().catch((err) => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
