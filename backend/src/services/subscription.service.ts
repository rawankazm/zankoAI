// ==============================================================================
// ZankoAI Premium Subscription Service
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { PaymentProviderRegistry } from './payment_providers/index.js';
import {
  SubscriptionPlanType,
  SubscriptionStatusResponse,
  CheckoutResult,
  SubscriptionRecord,
} from '../types/subscription.types.js';

export class SubscriptionService {
  private static readonly WEBHOOK_IDEMPOTENCY_PREFIX = 'zanko:sub_webhook:';

  /**
   * Retrieves current subscription for a user.
   * Performs automatic server-side expiration validation.
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

    // Server-side Expiration Check
    if (sub.status === 'active' && periodEnd < now) {
      logger.info('Subscription for user ' + userId + ' has expired on ' + sub.current_period_end + '. Downgrading to FREE.');

      await supabaseAdmin
        .from('subscriptions')
        .update({ status: 'expired', updated_at: now.toISOString() })
        .eq('id', sub.id);

      await supabaseAdmin
        .from('profiles')
        .update({
          plan: 'free',
          is_vip: false,
          vip_status: 'expired',
        })
        .eq('id', userId);

      await supabaseAdmin.from('subscription_events').insert({
        subscription_id: sub.id,
        user_id: userId,
        event_type: 'subscription.expired',
        provider: sub.provider,
        payload: { reason: 'period_end_passed', expired_at: now.toISOString() },
      });

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

    const isSubActive = sub.status === 'active' || sub.status === 'trialing';
    const daysRemaining = Math.max(
      0,
      Math.ceil((periodEnd.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    );

    return {
      hasActiveSubscription: isSubActive,
      isPremium: isSubActive && sub.plan !== 'FREE',
      plan: sub.plan as SubscriptionPlanType,
      status: sub.status,
      currentPeriodStart: sub.current_period_start,
      currentPeriodEnd: sub.current_period_end,
      cancelAtPeriodEnd: sub.cancel_at_period_end,
      provider: sub.provider,
      daysRemaining,
    };
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

    const checkout = await provider.createCheckout({
      userId: params.userId,
      userEmail: params.userEmail,
      plan: params.plan,
      returnUrl: params.returnUrl,
      cancelUrl: params.cancelUrl,
    });

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

    // 1. Verify and parse payload
    const event = await provider.handleWebhook(headers, rawBody);
    const idempotencyKey = event.idempotencyKey;

    // 2. Duplicate Webhook Protection via Redis and DB
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

    // 3. State Transitions based on verified event type
    let subscriptionId: string | undefined;

    if (
      event.eventType === 'payment.succeeded' ||
      event.eventType === 'subscription.renewed'
    ) {
      if (event.userId) {
        const plan = event.plan || 'PREMIUM_MONTHLY';
        const start = event.currentPeriodStart || new Date();
        const end = event.currentPeriodEnd || new Date(Date.now() + 30 * 86400000);

        // Upsert subscription record in database
        const { data: updatedSub, error: subErr } = await supabaseAdmin
          .from('subscriptions')
          .upsert(
            {
              user_id: event.userId,
              plan,
              status: 'active',
              provider: providerName,
              provider_subscription_id: event.providerSubscriptionId,
              provider_customer_id: event.providerCustomerId,
              current_period_start: start.toISOString(),
              current_period_end: end.toISOString(),
              cancel_at_period_end: false,
              updated_at: new Date().toISOString(),
            },
            { onConflict: 'user_id' }
          )
          .select()
          .single();

        if (subErr) {
          logger.error('Failed to update subscription in DB for user ' + event.userId + ':', subErr);
        } else {
          subscriptionId = updatedSub?.id;
        }

        // Elevate user profile to VIP and premium plan
        await supabaseAdmin
          .from('profiles')
          .update({
            plan: 'premium',
            is_vip: true,
            vip_status: 'active',
            vip_expires_at: end.toISOString(),
          })
          .eq('id', event.userId);

        logger.info('Activated premium subscription for user ' + event.userId + ' via ' + providerName);
      }
    } else if (event.eventType === 'payment.failed') {
      if (event.userId) {
        await supabaseAdmin
          .from('subscriptions')
          .update({ status: 'past_due', updated_at: new Date().toISOString() })
          .eq('user_id', event.userId);

        logger.warn('Marked subscription past_due for user ' + event.userId + ' due to payment failure');
      }
    } else if (event.eventType === 'subscription.canceled') {
      if (event.userId) {
        await supabaseAdmin
          .from('subscriptions')
          .update({
            status: 'canceled',
            cancel_at_period_end: true,
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', event.userId);

        logger.info('Marked subscription canceled for user ' + event.userId);
      }
    }

    // 4. Record Event Log
    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: subscriptionId,
      user_id: event.userId || '00000000-0000-0000-0000-000000000000',
      event_type: event.eventType,
      provider: providerName,
      provider_event_id: event.providerSubscriptionId,
      idempotency_key: idempotencyKey,
      payload: event.metadata || {},
    });

    return { handled: true, duplicate: false, eventType: event.eventType };
  }

  /**
   * Cancels subscription at period end.
   */
  static async cancelSubscription(userId: string): Promise<{ success: boolean; message: string }> {
    const { data: sub } = await supabaseAdmin
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .maybeSingle();

    if (!sub) {
      throw new Error('No active subscription found to cancel');
    }

    // Attempt provider-level cancel if provider is registered
    if (PaymentProviderRegistry.has(sub.provider) && sub.provider_subscription_id) {
      try {
        const provider = PaymentProviderRegistry.get(sub.provider);
        await provider.cancelSubscription(sub.provider_subscription_id);
      } catch (err: any) {
        logger.warn('Provider cancellation notice failed: ' + err.message);
      }
    }

    await supabaseAdmin
      .from('subscriptions')
      .update({
        cancel_at_period_end: true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', sub.id);

    await supabaseAdmin.from('subscription_events').insert({
      subscription_id: sub.id,
      user_id: userId,
      event_type: 'subscription.canceled',
      provider: sub.provider,
      payload: { cancel_at_period_end: true },
    });

    return {
      success: true,
      message: 'Subscription will remain active until ' + sub.current_period_end + ' and will not renew.',
    };
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
          vip_expires_at: verification.currentPeriodEnd.toISOString(),
        })
        .eq('id', userId);

      logger.info('Successfully verified and restored active subscription for user ' + userId);
    }

    return await this.getSubscription(userId);
  }
}
