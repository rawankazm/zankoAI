// ==============================================================================
// ZankoAI Premium Subscription Service — Complete Lifecycle & Maintenance Engine
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { NotificationService } from './notification.service.js';
import { UsageService } from './usage.service.js';
import { PaymentService } from './payment.service.js';
import {
  SubscriptionPlanType,
  SubscriptionStatusType,
  SubscriptionStatusResponse,
  SubscriptionRecord,
  SubscriptionHistoryResponse,
  SubscriptionMaintenanceResult,
  CheckoutResult,
  ActivateSubscriptionParams,
  RenewSubscriptionParams,
  CancelSubscriptionOptions,
} from '../types/subscription.types.js';
import { PaymentRecord } from '../types/payment.types.js';

export class SubscriptionService {
  private static readonly WEBHOOK_IDEMPOTENCY_PREFIX = 'zanko:sub_webhook:';
  private static readonly DEFAULT_GRACE_PERIOD_DAYS = 3;

  /**
   * 1. Retrieves current subscription for a user.
   * STRICT RULE: If current_period_end < now, the user cannot be treated as Premium.
   * Performs automatic server-side expiration validation and database synchronization.
   */
  static async getSubscription(userId: string): Promise<SubscriptionStatusResponse> {
    const { data: sub, error } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      logger.error('Error fetching subscription for user ' + userId + ':', error);
    }

    const res = await this.resolveSubscriptionStatus(userId, sub);
    try {
      res.usage = await UsageService.getUserUsageStatus(userId);
    } catch (uErr: any) {
      logger.warn('Failed to load usage status for user ' + userId + ': ' + uErr.message);
    }
    return res;
  }

  private static async resolveSubscriptionStatus(
    userId: string,
    sub: any
  ): Promise<SubscriptionStatusResponse> {
    if (!sub) {
      return {
        hasActiveSubscription: false,
        isPremium: false,
        plan: 'FREE',
        status: 'expired',
        cancelAtPeriodEnd: false,
      };
    }

    const now = new Date();
    const periodEnd = new Date(sub.current_period_end);
    const hasPeriodEnded = periodEnd.getTime() < now.getTime();

    // ── STRICT SERVER-SIDE EXPIRATION ENFORCEMENT ────────────────────────────
    // If period has ended:
    if (hasPeriodEnded) {
      // 1. If user was marked cancel_at_period_end or already past_due
      if (sub.cancel_at_period_end || sub.status === 'canceled') {
        if (sub.status !== 'expired') {
          await this.expireSubscription(sub.id, userId, 'period_end_passed_after_cancellation');
        }
        return {
          hasActiveSubscription: false,
          isPremium: false,
          plan: 'FREE',
          status: 'expired',
          currentPeriodStart: sub.current_period_start,
          currentPeriodEnd: sub.current_period_end,
          cancelAtPeriodEnd: sub.cancel_at_period_end,
          provider: sub.provider,
          daysRemaining: 0,
        };
      }

      // 2. If status is past_due, check if grace period has expired
      if (sub.status === 'past_due') {
        const graceEnd = sub.grace_period_end ? new Date(sub.grace_period_end) : null;
        if (!graceEnd || graceEnd.getTime() < now.getTime()) {
          await this.expireSubscription(sub.id, userId, 'grace_period_expired');
          return {
            hasActiveSubscription: false,
            isPremium: false,
            plan: 'FREE',
            status: 'expired',
            currentPeriodStart: sub.current_period_start,
            currentPeriodEnd: sub.current_period_end,
            cancelAtPeriodEnd: sub.cancel_at_period_end,
            provider: sub.provider,
            daysRemaining: 0,
          };
        }

        // Within grace period: User is past_due, NOT active premium
        return {
          hasActiveSubscription: false,
          isPremium: false,
          plan: sub.plan as SubscriptionPlanType,
          status: 'past_due',
          currentPeriodStart: sub.current_period_start,
          currentPeriodEnd: sub.current_period_end,
          cancelAtPeriodEnd: sub.cancel_at_period_end,
          inGracePeriod: true,
          gracePeriodEnd: sub.grace_period_end,
          provider: sub.provider,
          daysRemaining: 0,
        };
      }

      // 3. If status is still marked 'active' but current_period_end < now
      if (sub.status === 'active') {
        // Transition to past_due grace period or expire immediately
        const graceDays = sub.metadata?.grace_period_days ?? this.DEFAULT_GRACE_PERIOD_DAYS;
        if (graceDays > 0) {
          const graceEnd = new Date(periodEnd.getTime() + graceDays * 86400000);
          if (graceEnd.getTime() > now.getTime()) {
            await this.handleFailedRenewal({
              userId,
              subscriptionId: sub.id,
              reason: 'period_end_without_renewal',
              gracePeriodDays: graceDays,
            });

            return {
              hasActiveSubscription: false,
              isPremium: false,
              plan: sub.plan as SubscriptionPlanType,
              status: 'past_due',
              currentPeriodStart: sub.current_period_start,
              currentPeriodEnd: sub.current_period_end,
              cancelAtPeriodEnd: sub.cancel_at_period_end,
              inGracePeriod: true,
              gracePeriodEnd: graceEnd.toISOString(),
              provider: sub.provider,
              daysRemaining: 0,
            };
          }
        }

        // Otherwise expire immediately
        await this.expireSubscription(sub.id, userId, 'period_end_passed');
        return {
          hasActiveSubscription: false,
          isPremium: false,
          plan: 'FREE',
          status: 'expired',
          currentPeriodStart: sub.current_period_start,
          currentPeriodEnd: sub.current_period_end,
          cancelAtPeriodEnd: sub.cancel_at_period_end,
          provider: sub.provider,
          daysRemaining: 0,
        };
      }
    }

    // Period has NOT ended and status is active / trialing
    const isSubActive = (sub.status === 'active' || sub.status === 'trialing') && !hasPeriodEnded;
    const daysRemaining = Math.max(
      0,
      Math.ceil((periodEnd.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    );

    return {
      hasActiveSubscription: isSubActive,
      isPremium: isSubActive && sub.plan !== 'FREE',
      plan: sub.plan as SubscriptionPlanType,
      status: sub.status as SubscriptionStatusType,
      currentPeriodStart: sub.current_period_start,
      currentPeriodEnd: sub.current_period_end,
      cancelAtPeriodEnd: sub.cancel_at_period_end ?? false,
      inGracePeriod: false,
      gracePeriodEnd: sub.grace_period_end || null,
      autoRenew: sub.auto_renew ?? false,
      provider: sub.provider,
      daysRemaining,
    };
  }

  /**
   * 2. Activation Lifecycle Method
   * Grants Premium/VIP upon verified payment or administrator grant.
   */
  static async activateSubscription(params: ActivateSubscriptionParams): Promise<SubscriptionRecord> {
    const { userId, plan, provider, durationDays, providerSubscriptionId, providerCustomerId, autoRenew, metadata } = params;

    let periodDays = durationDays;
    if (!periodDays) {
      if (plan === 'PREMIUM_YEARLY') {
        periodDays = 365;
      } else {
        periodDays = 30;
      }
    }

    const now = new Date();
    // Check if user has an existing active subscription to prevent loss of remaining days
    const { data: existingSub } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();

    let startDate = now;
    let endDate: Date;

    if (existingSub && new Date(existingSub.current_period_end).getTime() > now.getTime()) {
      // Append period to existing active expiry
      const currentExpiry = new Date(existingSub.current_period_end);
      endDate = new Date(currentExpiry.getTime() + periodDays * 86400000);
      startDate = new Date(existingSub.current_period_start);
    } else {
      endDate = new Date(now.getTime() + periodDays * 86400000);
    }

    // Upsert subscription record
    const { data: sub, error: subErr } = await supabaseAdmin
      .from('subscriptions')
      .upsert(
        {
          user_id: userId,
          plan,
          status: 'active',
          provider,
          provider_subscription_id: providerSubscriptionId || null,
          provider_customer_id: providerCustomerId || null,
          current_period_start: startDate.toISOString(),
          current_period_end: endDate.toISOString(),
          cancel_at_period_end: false,
          grace_period_end: null,
          auto_renew: autoRenew ?? false,
          metadata: metadata || {},
          updated_at: now.toISOString(),
        },
        { onConflict: 'user_id' }
      )
      .select()
      .single();

    if (subErr) {
      logger.error('Failed to activate subscription in database: ' + subErr.message);
      throw subErr;
    }

    // Elevate user profile to VIP and Premium
    await supabaseAdmin
      .from('profiles')
      .update({
        plan: 'premium',
        is_vip: true,
        vip_status: 'active',
        vip_expiry: endDate.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('id', userId);

    // Record audit event
    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: sub.id,
      user_id: userId,
      event_type: 'subscription.activated',
      provider,
      provider_event_id: providerSubscriptionId || null,
      idempotency_key: params.idempotencyKey || ('act_' + userId + '_' + now.getTime()),
      payload: {
        plan,
        periodDays,
        current_period_start: startDate.toISOString(),
        current_period_end: endDate.toISOString(),
        autoRenew: autoRenew ?? false,
      },
    });

    // Send confirmation notification
    await NotificationService.scheduleNotification({
      userId,
      title: 'ZankoAI Premium Activated! 🌟',
      body: 'بەخێربێیت بۆ زانکۆ پرێمیۆم! هەموو تایبەتمەندییە زیرەکەکان بۆتۆ چالاککران.',
      type: 'subscription_notification',
      idempotencyKey: 'notif_sub_act_' + sub.id,
    });

    logger.info('Activated subscription ' + sub.id + ' for user ' + userId + ' until ' + endDate.toISOString());
    return sub as SubscriptionRecord;
  }

  /**
   * 3. Renewal Lifecycle Method
   * Extends subscription period seamlessly without losing remaining days.
   */
  static async renewSubscription(params: RenewSubscriptionParams): Promise<SubscriptionRecord> {
    const { userId, durationDays = 30, provider, providerSubscriptionId, autoRenew, metadata } = params;
    const now = new Date();

    const { data: existingSub } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    let newEndDate: Date;
    let startDate = now;

    if (existingSub && new Date(existingSub.current_period_end).getTime() > now.getTime()) {
      // Extend without gap from existing end date
      const currentEnd = new Date(existingSub.current_period_end);
      newEndDate = new Date(currentEnd.getTime() + durationDays * 86400000);
      startDate = new Date(existingSub.current_period_start);
    } else {
      newEndDate = new Date(now.getTime() + durationDays * 86400000);
    }

    const { data: sub, error: subErr } = await supabaseAdmin
      .from('subscriptions')
      .upsert(
        {
          user_id: userId,
          plan: existingSub?.plan || 'PREMIUM_MONTHLY',
          status: 'active',
          provider: provider || existingSub?.provider || 'sandbox',
          provider_subscription_id: providerSubscriptionId || existingSub?.provider_subscription_id || null,
          current_period_start: startDate.toISOString(),
          current_period_end: newEndDate.toISOString(),
          cancel_at_period_end: false,
          grace_period_end: null,
          auto_renew: autoRenew !== undefined ? autoRenew : (existingSub?.auto_renew ?? false),
          renewal_reminder_sent_at: null,
          metadata: { ...(existingSub?.metadata || {}), ...(metadata || {}) },
          updated_at: now.toISOString(),
        },
        { onConflict: 'user_id' }
      )
      .select()
      .single();

    if (subErr) {
      logger.error('Failed to renew subscription: ' + subErr.message);
      throw subErr;
    }

    // Re-elevate profile VIP
    await supabaseAdmin
      .from('profiles')
      .update({
        plan: 'premium',
        is_vip: true,
        vip_status: 'active',
        vip_expiry: newEndDate.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('id', userId);

    // Audit event log
    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: sub.id,
      user_id: userId,
      event_type: 'subscription.renewed',
      provider: sub.provider,
      provider_event_id: providerSubscriptionId || null,
      idempotency_key: params.idempotencyKey || ('renew_' + userId + '_' + now.getTime()),
      payload: {
        new_period_end: newEndDate.toISOString(),
        durationDays,
      },
    });

    // Notify user of successful renewal
    await NotificationService.scheduleNotification({
      userId,
      title: 'Subscription Renewed! 🚀',
      body: 'ئابوونەی پرێمیۆمەکەت بەسەرکەوتوویی نوێکرایەوە تا بەرواری ' + newEndDate.toLocaleDateString(),
      type: 'subscription_notification',
      idempotencyKey: 'notif_sub_renew_' + sub.id + '_' + newEndDate.getTime(),
    });

    logger.info('Renewed subscription ' + sub.id + ' for user ' + userId + ' until ' + newEndDate.toISOString());
    return sub as SubscriptionRecord;
  }

  /**
   * 4. Cancellation Lifecycle Method
   * Supports 'cancel at period end' (default) and 'immediate cancellation'.
   */
  static async cancelSubscription(
    userId: string,
    options?: CancelSubscriptionOptions
  ): Promise<{ success: boolean; message: string; status: SubscriptionStatusType }> {
    const { data: sub } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();

    if (!sub) {
      throw new Error('No active subscription found to cancel');
    }

    const now = new Date();
    const isImmediate = options?.immediate === true;

    // If external provider supports recurring cancellation (e.g. Stripe)
    if (PaymentProviderRegistry.has(sub.provider) && sub.provider_subscription_id) {
      try {
        const provider = PaymentProviderRegistry.get(sub.provider);
        if (provider.supportsRecurring) {
          await provider.cancelSubscription(sub.provider_subscription_id);
        }
      } catch (err: any) {
        logger.warn('Provider cancellation notice warning: ' + err.message);
      }
    }

    if (isImmediate) {
      // Immediate cancellation
      await supabaseAdmin
        .from('subscriptions')
        .update({
          status: 'canceled',
          cancel_at_period_end: false,
          updated_at: now.toISOString(),
        })
        .eq('id', sub.id);

      await supabaseAdmin
        .from('profiles')
        .update({
          is_vip: false,
          plan: 'free',
          vip_status: 'canceled',
          updated_at: now.toISOString(),
        })
        .eq('id', userId);

      await supabaseAdmin.from('subscription_events').insert({
        subscription_id: sub.id,
        user_id: userId,
        event_type: 'subscription.canceled_immediately',
        provider: sub.provider,
        payload: { reason: options?.reason || 'user_requested_immediate' },
      });

      return {
        success: true,
        message: 'Your subscription has been canceled immediately.',
        status: 'canceled',
      };
    }

    // Default: Cancel at period end
    await supabaseAdmin
      .from('subscriptions')
      .update({
        cancel_at_period_end: true,
        auto_renew: false,
        updated_at: now.toISOString(),
      })
      .eq('id', sub.id);

    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: sub.id,
      user_id: userId,
      event_type: 'subscription.cancel_scheduled',
      provider: sub.provider,
      payload: { cancel_at_period_end: true, reason: options?.reason || 'user_requested' },
    });

    return {
      success: true,
      message: 'Subscription will remain active until ' + sub.current_period_end + ' and will not renew.',
      status: 'active',
    };
  }

  /**
   * 5. Expiration Lifecycle Method
   * Marks subscription expired and strictly strips VIP privileges.
   */
  static async expireSubscription(subscriptionId: string, userId: string, reason = 'period_end_passed'): Promise<void> {
    const now = new Date();

    await supabaseAdmin
      .from('subscriptions')
      .update({
        status: 'expired',
        grace_period_end: null,
        auto_renew: false,
        updated_at: now.toISOString(),
      })
      .eq('id', subscriptionId);

    await supabaseAdmin
      .from('profiles')
      .update({
        plan: 'free',
        is_vip: false,
        vip_status: 'expired',
        updated_at: now.toISOString(),
      })
      .eq('id', userId);

    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: subscriptionId,
      user_id: userId,
      event_type: 'subscription.expired',
      provider: 'system',
      payload: { reason, expired_at: now.toISOString() },
    });

    await NotificationService.scheduleNotification({
      userId,
      title: 'Premium Subscription Expired ⏳',
      body: 'ئابوونەی پرێمیۆمەکەت بەسەرچوو. دەتوانیت لە هەر کاتێکدا نوێی بکەیتەوە بۆ بەردەوامبوون لە خزمەتگوزارییەکان.',
      type: 'subscription_notification',
      idempotencyKey: 'notif_sub_exp_' + subscriptionId,
    });

    logger.info('Marked subscription ' + subscriptionId + ' expired for user ' + userId);
  }

  /**
   * 6. Failed Renewal & Grace Period Handling
   * Puts subscription into 'past_due' with grace period deadline.
   */
  static async handleFailedRenewal(params: {
    userId: string;
    subscriptionId?: string;
    reason?: string;
    gracePeriodDays?: number;
  }): Promise<SubscriptionRecord | null> {
    const { userId, subscriptionId, reason = 'payment_declined', gracePeriodDays = SubscriptionService.DEFAULT_GRACE_PERIOD_DAYS } = params;
    const now = new Date();
    const graceEnd = new Date(now.getTime() + gracePeriodDays * 86400000);

    let query = supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId);

    if (subscriptionId) {
      query = query.eq('id', subscriptionId);
    }

    const { data: sub } = await query.order('created_at', { ascending: false }).limit(1).maybeSingle();
    if (!sub) return null;

    const { data: updatedSub } = await supabaseAdmin
      .from('subscriptions')
      .update({
        status: 'past_due',
        grace_period_end: graceEnd.toISOString(),
        updated_at: now.toISOString(),
        metadata: {
          ...(sub.metadata || {}),
          last_failure_reason: reason,
          failed_at: now.toISOString(),
        },
      })
      .eq('id', sub.id)
      .select()
      .single();

    await supabaseAdmin
      .from('profiles')
      .update({
        vip_status: 'past_due',
        updated_at: now.toISOString(),
      })
      .eq('id', userId);

    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: sub.id,
      user_id: userId,
      event_type: 'subscription.renewal_failed',
      provider: sub.provider,
      payload: {
        reason,
        grace_period_days: gracePeriodDays,
        grace_period_end: graceEnd.toISOString(),
      },
    });

    // Notify user of failed payment and grace period
    await NotificationService.scheduleNotification({
      userId,
      title: 'Payment Renewal Notice ⚠️',
      body: 'نوێکردنەوەی ئابوونەکەت سەرکەوتوو نەبوو. تکایە لە ماوەی ٣ ڕۆژدا کارت یان باڵانسی مۆبایلت نوێ بکەرەوە.',
      type: 'subscription_notification',
      idempotencyKey: 'notif_sub_failed_' + sub.id + '_' + now.getDate(),
    });

    logger.warn('Subscription ' + sub.id + ' entered past_due grace period until ' + graceEnd.toISOString());
    return updatedSub as SubscriptionRecord;
  }

  /**
   * 7. History Aggregator: GET /api/subscription/history
   * Aggregates subscriptions, payments, and event audit history for the user.
   */
  static async getSubscriptionHistory(userId: string): Promise<SubscriptionHistoryResponse> {
    // 1. Subscriptions history
    const { data: subs, error: subErr } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (subErr) {
      logger.error('Error fetching subscriptions history for user ' + userId + ':', subErr);
    }

    // 2. Payments history
    const { data: payments, error: payErr } = await supabaseAdmin
      .from('payments')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (payErr) {
      logger.error('Error fetching payments history for user ' + userId + ':', payErr);
    }

    // 3. Events history
    const { data: events, error: evtErr } = await supabaseAdmin
      .from('subscription_events')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (evtErr) {
      logger.error('Error fetching subscription events history for user ' + userId + ':', evtErr);
    }

    return {
      subscriptions: (subs || []) as SubscriptionRecord[],
      payments: (payments || []) as PaymentRecord[],
      events: events || [],
    };
  }

  /**
   * 8. Scheduled Maintenance Processor: subscription-maintenance
   * Detects expired subscriptions, updates statuses, processes pending states,
   * triggers renewal reminders, and notifies users.
   */
  static async runMaintenance(): Promise<SubscriptionMaintenanceResult> {
    const now = new Date();
    const result: SubscriptionMaintenanceResult = {
      scannedCount: 0,
      expiredCount: 0,
      pastDueCount: 0,
      remindersSentCount: 0,
      stalePendingProcessed: 0,
      timestamp: now.toISOString(),
    };

    logger.info('Starting subscription-maintenance routine at ' + now.toISOString());

    // ── STEP A: Detect Expired Subscriptions ─────────────────────────────────
    // 1. Expired active subscriptions with cancel_at_period_end = true
    const { data: cancelledExpired } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('status', 'active')
      .eq('cancel_at_period_end', true)
      .lt('current_period_end', now.toISOString());

    for (const sub of (cancelledExpired || [])) {
      result.scannedCount++;
      await this.expireSubscription(sub.id, sub.user_id, 'cancel_at_period_end_reached');
      result.expiredCount++;
    }

    // 2. Expired past_due subscriptions whose grace_period_end has elapsed
    const { data: pastDueExpired } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('status', 'past_due')
      .lt('grace_period_end', now.toISOString());

    for (const sub of (pastDueExpired || [])) {
      result.scannedCount++;
      await this.expireSubscription(sub.id, sub.user_id, 'grace_period_exhausted');
      result.expiredCount++;
    }

    // 3. Active subscriptions whose current_period_end < now (not yet cancelled)
    const { data: activePastEnd } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('status', 'active')
      .eq('cancel_at_period_end', false)
      .lt('current_period_end', now.toISOString());

    for (const sub of (activePastEnd || [])) {
      result.scannedCount++;

      // RULE: Do not charge automatically unless provider explicitly supports AND user authorized recurring billing
      const provider = PaymentProviderRegistry.has(sub.provider)
        ? PaymentProviderRegistry.get(sub.provider)
        : null;

      const canAutoCharge = provider?.supportsRecurring === true && sub.auto_renew === true;

      if (canAutoCharge && sub.provider_subscription_id) {
        // Attempt recurring charge via provider
        logger.info('Attempting authorized recurring renewal charge for user ' + sub.user_id);
        try {
          // If provider renews successfully:
          await this.renewSubscription({
            userId: sub.user_id,
            durationDays: 30,
            provider: sub.provider,
            providerSubscriptionId: sub.provider_subscription_id,
          });
          continue;
        } catch (err: any) {
          logger.warn('Recurring charge failed for user ' + sub.user_id + ': ' + err.message);
        }
      }

      // If cannot auto charge or charge failed, enter grace period
      await this.handleFailedRenewal({
        userId: sub.user_id,
        subscriptionId: sub.id,
        reason: canAutoCharge ? 'recurring_charge_failed' : 'manual_renewal_required',
        gracePeriodDays: this.DEFAULT_GRACE_PERIOD_DAYS,
      });
      result.pastDueCount++;
    }

    // ── STEP B: Trigger Renewal Reminders & Notify Users ─────────────────────
    // Remind users whose subscription ends in 3 days (within 72 hours) and hasn't received reminder
    const inThreeDays = new Date(now.getTime() + 3 * 86400000);
    const { data: expiringSoon } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('status', 'active')
      .lte('current_period_end', inThreeDays.toISOString())
      .gt('current_period_end', now.toISOString())
      .is('renewal_reminder_sent_at', null);

    for (const sub of (expiringSoon || [])) {
      result.scannedCount++;
      const periodEnd = new Date(sub.current_period_end);
      const daysLeft = Math.max(1, Math.ceil((periodEnd.getTime() - now.getTime()) / 86400000));

      await NotificationService.scheduleNotification({
        userId: sub.user_id,
        title: 'Subscription Expiring Soon! ⏰',
        body: 'ئابوونەی پرێمیۆمەکەت دوای ' + daysLeft + ' ڕۆژی تر تەواو دەبێت. نوێی بکەرەوە بۆ بەردەوامبوونی تایبەتمەندییەکان.',
        type: 'subscription_notification',
        idempotencyKey: 'notif_remind_' + sub.id + '_' + sub.current_period_end.slice(0, 10),
      });

      await supabaseAdmin
        .from('subscriptions')
        .update({ renewal_reminder_sent_at: now.toISOString() })
        .eq('id', sub.id);

      result.remindersSentCount++;
    }

    // ── STEP C: Process Pending States (Stale Checkouts) ─────────────────────
    // Mark pending checkouts older than 2 hours as 'failed' to prevent hung UI
    const twoHoursAgo = new Date(now.getTime() - 2 * 3600000);
    const { data: stalePayments } = await supabaseAdmin
      .from('payments')
      .select('*')
      .eq('status', 'pending')
      .lt('created_at', twoHoursAgo.toISOString());

    for (const payment of (stalePayments || [])) {
      await supabaseAdmin
        .from('payments')
        .update({
          status: 'failed',
          metadata: { ...(payment.metadata || {}), failure_reason: 'checkout_session_timed_out' },
          updated_at: now.toISOString(),
        })
        .eq('id', payment.id);

      result.stalePendingProcessed++;
    }

    logger.info(
      'subscription-maintenance finished: ' +
      result.scannedCount + ' scanned, ' +
      result.expiredCount + ' expired, ' +
      result.pastDueCount + ' past due, ' +
      result.remindersSentCount + ' reminders sent, ' +
      result.stalePendingProcessed + ' stale payments cleaned'
    );

    return result;
  }

  /**
   * Initiates a verified checkout session with a pluggable payment provider.
   */
  static async createCheckout(params: {
    userId: string;
    userEmail?: string;
    plan: SubscriptionPlanType;
    providerName: string;
    returnUrl?: string;
    cancelUrl?: string;
  }): Promise<CheckoutResult> {
    const provider = PaymentProviderRegistry.get(params.providerName);

    let checkout: CheckoutResult;
    if (typeof (provider as any).createCheckout === 'function') {
      checkout = await (provider as any).createCheckout({
        userId: params.userId,
        userEmail: params.userEmail,
        plan: params.plan,
        returnUrl: params.returnUrl,
        cancelUrl: params.cancelUrl,
      });
    } else {
      const payment = await PaymentService.createCheckout({
        userId: params.userId,
        userEmail: params.userEmail,
        plan: params.plan,
        providerName: params.providerName,
        returnUrl: params.returnUrl,
        cancelUrl: params.cancelUrl,
      });

      checkout = {
        checkoutId: payment.orderId || payment.transactionId || 'chk_' + Date.now(),
        checkoutUrl: payment.paymentUrl,
        qrPayload: payment.qrPayload,
        provider: params.providerName,
        plan: params.plan,
        amount: payment.amount ?? PaymentService.getPlanPriceIqd(params.plan),
        currency: payment.currency || 'IQD',
      };
    }

    // Record checkout event
    await supabaseAdmin.from('subscription_events').insert({
      user_id: params.userId,
      event_type: 'checkout.created',
      provider: params.providerName,
      provider_event_id: checkout.checkoutId,
      idempotency_key: 'checkout_' + checkout.checkoutId,
      payload: {
        plan: params.plan,
        amount: checkout.amount,
        currency: checkout.currency,
      },
    });

    return checkout;
  }

  /**
   * Processes inbound provider webhooks with strict idempotency and cryptographic verification.
   */
  static async processWebhook(
    providerName: string,
    headers: Record<string, string>,
    rawBody: any
  ): Promise<{ handled: boolean; duplicate: boolean; eventType: string }> {
    const provider = PaymentProviderRegistry.get(providerName);

    const event = await provider.handleWebhook(headers, rawBody);
    const idempotencyKey = event.idempotencyKey;

    const redisKey = this.WEBHOOK_IDEMPOTENCY_PREFIX + idempotencyKey;
    const isNewRedisLock = await redis.set(redisKey, 'processing', 'EX', 86400, 'NX');

    if (!isNewRedisLock) {
      logger.warn('Duplicate webhook detected in Redis cache for key: ' + idempotencyKey);
      return { handled: true, duplicate: true, eventType: event.eventType };
    }

    const { data: existingEvent } = await supabaseAdmin
      .from('subscription_events')
      .select('id')
      .eq('idempotency_key', idempotencyKey)
      .maybeSingle();

    if (existingEvent) {
      logger.warn('Duplicate webhook already recorded in database: ' + idempotencyKey);
      return { handled: true, duplicate: true, eventType: event.eventType };
    }

    let subscriptionId: string | undefined;

    if (
      event.eventType === 'payment.succeeded' ||
      event.eventType === 'subscription.renewed'
    ) {
      if (event.userId) {
        const sub = await this.activateSubscription({
          userId: event.userId,
          plan: event.plan || 'PREMIUM_MONTHLY',
          provider: providerName,
          providerSubscriptionId: event.providerSubscriptionId,
          providerCustomerId: event.providerCustomerId,
          idempotencyKey,
        });
        subscriptionId = sub.id;
      }
    } else if (event.eventType === 'payment.failed') {
      if (event.userId) {
        await this.handleFailedRenewal({
          userId: event.userId,
          reason: 'webhook_payment_failed',
        });
      }
    } else if (event.eventType === 'subscription.canceled') {
      if (event.userId) {
        await this.cancelSubscription(event.userId, { immediate: false });
      }
    }

    return { handled: true, duplicate: false, eventType: event.eventType };
  }

  /**
   * Restores subscription through direct server-to-server provider verification.
   * Client claims are never trusted.
   */
  static async restoreSubscription(userId: string): Promise<SubscriptionStatusResponse> {
    const { data: sub } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!sub || !sub.provider_subscription_id || !PaymentProviderRegistry.has(sub.provider)) {
      return await this.getSubscription(userId);
    }

    const provider = PaymentProviderRegistry.get(sub.provider);
    const verification = await provider.getSubscription(sub.provider_subscription_id);

    if (verification.verified && verification.status === 'active') {
      await supabaseAdmin
        .from('subscriptions')
        .update({
          status: 'active',
          current_period_end: verification.currentPeriodEnd.toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', sub.id);

      await supabaseAdmin
        .from('profiles')
        .update({
          plan: 'premium',
          is_vip: true,
          vip_status: 'active',
          vip_expiry: verification.currentPeriodEnd.toISOString(),
        })
        .eq('id', userId);

      logger.info('Successfully verified and restored active subscription for user ' + userId);
    }

    return await this.getSubscription(userId);
  }
}
