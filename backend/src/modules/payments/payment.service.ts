import axios from 'axios';
import { env } from '../../config/env.js';
import { supabaseAdmin } from '../../config/supabase.js';
import { logger } from '../../config/logger.js';

export interface PaymentInitiationResult {
  transactionId: string;
  gateway: string;
  qrPayload?: string;
  paymentUrl?: string;
  status: string;
}

export class PaymentService {
  /**
   * Initiate payment with First Iraqi Bank (FIB)
   */
  async initiateFibPayment(userId: string, planId: string): Promise<PaymentInitiationResult> {
    // 1. Fetch Plan Details
    const { data: plan, error: planErr } = await supabaseAdmin
      .from('subscription_plans')
      .select('*')
      .eq('id', planId)
      .single();

    if (planErr || !plan) {
      throw new Error('Subscription plan not found');
    }

    // 2. Create Transaction Record in Supabase
    const { data: transaction, error: txErr } = await supabaseAdmin
      .from('payment_transactions')
      .insert({
        user_id: userId,
        plan_id: planId,
        amount_iqd: plan.price_iqd,
        gateway: 'fib',
        status: 'initiated',
      })
      .select()
      .single();

    if (txErr || !transaction) {
      throw new Error(`Failed to create transaction record: ${txErr?.message}`);
    }

    // 3. Connect to FIB Corporate API (Simulated or Live depending on ENV)
    try {
      if (env.FIB_CLIENT_ID && env.FIB_CLIENT_SECRET) {
        // Live FIB Integration
        const tokenRes = await axios.post(`${env.FIB_BASE_URL}/auth/realms/fib-online-shop/protocol/openid-connect/token`, {
          grant_type: 'client_credentials',
          client_id: env.FIB_CLIENT_ID,
          client_secret: env.FIB_CLIENT_SECRET,
        });
        const accessToken = tokenRes.data.access_token;

        const fibPaymentRes = await axios.post(
          `${env.FIB_BASE_URL}/protected/v1/payments`,
          {
            monetaryValue: { amount: plan.price_iqd, currency: 'IQD' },
            statusCallbackUrl: `${env.API_PREFIX}/payments/webhook/fib`,
            description: `ZankoAI VIP Subscription - ${plan.title_ku}`,
          },
          { headers: { Authorization: `Bearer ${accessToken}` } }
        );

        const { paymentId, qrCode, readableCode } = fibPaymentRes.data;

        await supabaseAdmin
          .from('payment_transactions')
          .update({
            gateway_reference_id: paymentId,
            gateway_qr_payload: qrCode || readableCode,
            status: 'pending',
          })
          .eq('id', transaction.id);

        return {
          transactionId: transaction.id,
          gateway: 'fib',
          qrPayload: qrCode || readableCode,
          status: 'pending',
        };
      }
    } catch (err: any) {
      logger.warn('FIB Live Gateway connection fallback to dynamic merchant QR:', err.message);
    }

    // Fallback QR code representation for FIB direct account transfer
    const simulatedQr = `fib://pay?account=FIB-ZANKO-9090&amount=${plan.price_iqd}&ref=${transaction.id}`;
    await supabaseAdmin
      .from('payment_transactions')
      .update({ gateway_qr_payload: simulatedQr, status: 'pending' })
      .eq('id', transaction.id);

    return {
      transactionId: transaction.id,
      gateway: 'fib',
      qrPayload: simulatedQr,
      status: 'pending',
    };
  }

  /**
   * Redeem a Prepaid Voucher Code (Scratch Card)
   */
  async redeemVoucher(userId: string, code: string): Promise<{ success: boolean; plan: any }> {
    const cleanCode = code.trim().toUpperCase();

    // 1. Look up voucher
    const { data: voucher, error: vErr } = await supabaseAdmin
      .from('vouchers')
      .select('*, subscription_plans(*)')
      .eq('code', cleanCode)
      .eq('is_redeemed', false)
      .single();

    if (vErr || !voucher) {
      throw new Error('کۆدەکە هەڵەیە یان پێشتر بەکارهاتووە (Invalid or already redeemed voucher code)');
    }

    if (new Date(voucher.expires_at) < new Date()) {
      throw new Error('ئەم کۆدە بەسەرچووە (Voucher code has expired)');
    }

    const plan = voucher.subscription_plans;
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + plan.duration_days);

    // 2. Mark voucher as redeemed
    await supabaseAdmin
      .from('vouchers')
      .update({
        is_redeemed: true,
        redeemed_by: userId,
        redeemed_at: new Date().toISOString(),
      })
      .eq('id', voucher.id);

    // 3. Activate VIP status for user
    await supabaseAdmin
      .from('users')
      .update({
        is_vip: true,
        vip_status: 'active',
        vip_expires_at: expiryDate.toISOString(),
      })
      .eq('id', userId);

    // 4. Record transaction log
    await supabaseAdmin.from('payment_transactions').insert({
      user_id: userId,
      plan_id: voucher.plan_id,
      amount_iqd: plan.price_iqd,
      gateway: 'voucher',
      gateway_reference_id: cleanCode,
      status: 'completed',
    });

    return { success: true, plan };
  }

  /**
   * Webhook Handler for FIB / FastPay payment completion
   */
  async handlePaymentWebhook(gateway: string, payload: any): Promise<boolean> {
    logger.info(`Received inbound payment webhook from ${gateway}:`, payload);
    const referenceId = payload.paymentId || payload.orderId || payload.ref;
    const status = payload.status;

    if (status === 'PAID' || status === 'SUCCESS' || status === 'COMPLETED') {
      const { data: tx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*, subscription_plans(*)')
        .eq('gateway_reference_id', referenceId)
        .single();

      if (tx) {
        const plan = tx.subscription_plans;
        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + (plan?.duration_days || 30));

        await supabaseAdmin
          .from('payment_transactions')
          .update({ status: 'completed', updated_at: new Date().toISOString() })
          .eq('id', tx.id);

        await supabaseAdmin
          .from('users')
          .update({
            is_vip: true,
            vip_status: 'active',
            vip_expires_at: expiryDate.toISOString(),
          })
          .eq('id', tx.user_id);

        logger.info(`Successfully activated VIP for user ${tx.user_id} via ${gateway}`);
        return true;
      }
    }
    return false;
  }
}

export const paymentService = new PaymentService();
