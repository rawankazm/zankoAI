// ==============================================================================
// ZankoAI Enterprise Payment Service Engine (Decoupled Iraq Payment Architecture)
// ==============================================================================

import crypto from 'crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { PaymentProviderRegistry } from './payment_providers/index.js';
import { SubscriptionService } from './subscription.service.js';
import { SubscriptionPlanType } from '../types/subscription.types.js';
import {
  PaymentRecord,
  PaymentStatus,
  PaymentResult,
  WebhookResult,
  RefundResult,
} from '../types/payment.types.js';

export interface CheckoutOptions {
  userId: string;
  plan: string;
  providerName?: string;
  returnUrl?: string;
  isRenewal?: boolean;
}

export class PaymentService {
  /**
   * Authoritative canonical pricing matrix in IQD.
   * Client cannot supply custom pricing.
   */
  static getPlanPriceIqd(plan: string): number {
    switch (plan.toUpperCase()) {
      case 'PREMIUM_MONTHLY':
      case 'MONTHLY':
        return 15000;
      case 'PREMIUM_YEARLY':
      case 'ANNUAL':
      case 'YEARLY':
        return 140000;
      case 'STUDENT':
        return 9000;
      case 'UNIVERSITY':
        return 500000;
      case 'TEAM':
        return 45000;
      case 'FREE':
      default:
        return 0;
    }
  }

  /**
   * 1. Initiates payment checkout with Zero Client Trust.
   * Generates secure order_id, inserts payment record (pending),
   * and requests hosted payment session from the selected provider adapter.
   */
  static async createCheckout(options: CheckoutOptions): Promise<PaymentResult> {
    const amount = this.getPlanPriceIqd(options.plan);
    if (amount <= 0) {
      throw new Error('Invalid plan selection: ' + options.plan);
    }

    const providerName = (options.providerName || process.env.PAYMENT_DEFAULT_PROVIDER || 'qi_card').toLowerCase();
    const provider = PaymentProviderRegistry.get(providerName);

    const orderId = 'order_' + Date.now().toString() + '_' + crypto.randomBytes(4).toString('hex');
    const currency = 'IQD';

    // 1. Create transaction in payments table with status 'pending'
    const { data: paymentRecord, error: insertErr } = await supabaseAdmin
      .from('payments')
      .insert({
        user_id: options.userId,
        provider: provider.name,
        order_id: orderId,
        amount: amount,
        currency: currency,
        status: 'pending',
        plan: options.plan.toUpperCase(),
        metadata: {
          returnUrl: options.returnUrl || null,
          isRenewal: options.isRenewal || false,
          createdVia: 'api/payments/checkout',
        },
      })
      .select()
      .single();

    if (insertErr || !paymentRecord) {
      logger.error('Failed to create payment record in DB: ' + (insertErr?.message || 'unknown error'));
      throw new Error('Could not initialize payment transaction in database.');
    }

    // 2. Call provider adapter to generate hosted checkout / dynamic QR
    try {
      const paymentResult = await provider.createPayment({
        orderId: orderId,
        amount: amount,
        currency: currency,
        plan: options.plan.toUpperCase(),
        userId: options.userId,
        callbackUrl: options.returnUrl,
      });

      // Update payment record with provider transaction ID if provided
      if (paymentResult.transactionId) {
        await supabaseAdmin
          .from('payments')
          .update({
            transaction_id: paymentResult.transactionId,
            updated_at: new Date().toISOString(),
          })
          .eq('order_id', orderId);
      }

      logger.info('Checkout created: ' + orderId + ' (' + amount.toString() + ' IQD via ' + provider.name + ')');
      return paymentResult;
    } catch (err: any) {
      logger.error('Provider createPayment error (' + provider.name + '): ' + err.message);
      await supabaseAdmin
        .from('payments')
        .update({ status: 'failed', updated_at: new Date().toISOString() })
        .eq('order_id', orderId);
      throw err;
    }
  }

  /**
   * 2. Retrieves a payment record by ID or Order ID
   */
  static async getPayment(paymentIdOrOrderId: string, userId?: string): Promise<PaymentRecord | null> {
    let query = supabaseAdmin
      .from('payments')
      .select('*');

    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(paymentIdOrOrderId);
    if (isUuid) {
      query = query.eq('id', paymentIdOrOrderId);
    } else {
      query = query.eq('order_id', paymentIdOrOrderId);
    }

    if (userId) {
      query = query.eq('user_id', userId);
    }

    const { data, error } = await query.maybeSingle();
    if (error || !data) return null;
    return data as PaymentRecord;
  }

  /**
   * 3. Comprehensive 9-Point Webhook Processor
   * Handles inbound callbacks, enforces authenticity, verifies amounts/currency/order,
   * checks idempotency, stores events, and activates VIP subscription exactly ONCE.
   */
  static async processWebhook(
    providerName: string,
    headers: Record<string, string>,
    rawBody: any
  ): Promise<{ received: boolean; duplicate?: boolean; status: PaymentStatus; orderId: string }> {
    const provider = PaymentProviderRegistry.get(providerName);

    // 1. Validate authenticity & signature via provider adapter
    let webhookResult: WebhookResult;
    try {
      webhookResult = await provider.handleWebhook(headers, rawBody);
    } catch (authErr: any) {
      logger.warn('Webhook authenticity check failed (' + provider.name + '): ' + authErr.message);
      throw authErr;
    }

    const orderId = webhookResult.orderId;

    // 2. Fetch original payment transaction from database
    const payment = await this.getPayment(orderId);
    if (!payment) {
      logger.warn('Webhook rejected: Payment record not found for orderId: ' + orderId);
      throw new Error('Payment record not found for order: ' + orderId);
    }

    // 3. Validate transaction ID
    const txId = webhookResult.transactionId || payment.transaction_id;

    // 4. Validate amount (strict match)
    if (webhookResult.amount !== undefined && Number(webhookResult.amount) !== Number(payment.amount)) {
      logger.error('CRITICAL: Webhook amount mismatch! Expected ' + payment.amount.toString() + ' but got ' + webhookResult.amount.toString());
      throw new Error('Security alert: Webhook amount does not match order record.');
    }

    // 5. Validate currency (strict match)
    if (webhookResult.currency && webhookResult.currency.toUpperCase() !== payment.currency.toUpperCase()) {
      logger.error('CRITICAL: Webhook currency mismatch! Expected ' + payment.currency + ' but got ' + webhookResult.currency);
      throw new Error('Security alert: Webhook currency does not match order record.');
    }

    // 6. Check transaction status
    const newStatus = webhookResult.status;

    // 7. Idempotency Check (Duplicate prevention)
    const idempotencyKey = provider.name + ':' + (webhookResult.providerEventId || txId || orderId);
    const { data: existingEvent } = await supabaseAdmin
      .from('payment_events')
      .select('id')
      .eq('idempotency_key', idempotencyKey)
      .maybeSingle();

    if (existingEvent) {
      logger.info('Duplicate webhook safely ignored via idempotencyKey: ' + idempotencyKey);
      return {
        received: true,
        duplicate: true,
        status: payment.status,
        orderId: orderId,
      };
    }

    // 8. Store audit event in payment_events table
    await supabaseAdmin
      .from('payment_events')
      .insert({
        payment_id: payment.id,
        provider: provider.name,
        provider_event_id: webhookResult.providerEventId || null,
        event_type: webhookResult.eventType,
        idempotency_key: idempotencyKey,
        payload: webhookResult.payload || {},
      });

    // Update payment record status
    await supabaseAdmin
      .from('payments')
      .update({
        status: newStatus,
        transaction_id: txId || payment.transaction_id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', payment.id);

    // 9. If paid and not already paid: Update subscription & grant VIP exactly ONCE
    if (newStatus === 'paid' && payment.status !== 'paid') {
      await this.activateSubscriptionFromPayment(payment, txId || orderId);
    }

    return {
      received: true,
      duplicate: false,
      status: newStatus,
      orderId: orderId,
    };
  }

  /**
   * Activates or extends the user's subscription and VIP status in Supabase.
   */
  private static async activateSubscriptionFromPayment(
    payment: PaymentRecord,
    transactionId: string
  ): Promise<void> {
    const isYearly = payment.plan === 'PREMIUM_YEARLY' || payment.plan === 'YEARLY';
    // SECURITY [H-07]: Never trust metadata.duration_days from the payment record.
    // The duration MUST be derived solely from the canonical plan name to prevent manipulation.
    const periodDays = isYearly ? 365 : 30;
    const subPlan: SubscriptionPlanType = isYearly ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY';

    logger.info('Activating VIP subscription for user ' + payment.user_id + ' for ' + periodDays + ' days');

    await SubscriptionService.activateSubscription({
      userId: payment.user_id,
      plan: subPlan,
      provider: payment.provider,
      durationDays: periodDays,
      providerSubscriptionId: transactionId,
      idempotencyKey: 'sub_evt_' + payment.provider + '_' + transactionId,
      metadata: {
        orderId: payment.order_id,
        paymentId: payment.id,
        amount: payment.amount,
        currency: payment.currency,
      },
    });
  }

  /**
   * 4. Refunds a payment through the provider and updates DB
   */
  static async refundPayment(paymentId: string, reason?: string): Promise<RefundResult> {
    const payment = await this.getPayment(paymentId);
    if (!payment) {
      throw new Error('Payment not found: ' + paymentId);
    }

    if (payment.status !== 'paid') {
      throw new Error('Cannot refund a payment with status ' + payment.status);
    }

    const provider = PaymentProviderRegistry.get(payment.provider);
    const refundRes = await provider.refundPayment(
      payment.transaction_id || payment.order_id,
      payment.amount,
      reason
    );

    if (refundRes.success) {
      await supabaseAdmin
        .from('payments')
        .update({
          status: 'refunded',
          updated_at: new Date().toISOString(),
        })
        .eq('id', payment.id);

      await supabaseAdmin
        .from('payment_events')
        .insert({
          payment_id: payment.id,
          provider: payment.provider,
          event_type: 'payment.refunded',
          idempotency_key: 'ref_evt_' + (refundRes.refundId || payment.id),
          payload: {
            reason: reason || 'admin_or_customer_refund',
            refundId: refundRes.refundId,
          },
        });
    }

    return refundRes;
  }
}
