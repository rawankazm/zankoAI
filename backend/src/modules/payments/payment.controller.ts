import { Request, Response, NextFunction } from 'express';
import { paymentService } from './payment.service.js';
import { supabaseAdmin } from '../../config/supabase.js';
import { z } from 'zod';

const fibCheckoutSchema = z.object({
  planId: z.string().min(1),
});

const redeemVoucherSchema = z.object({
  code: z.string().min(4),
});

export const getPlansHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('subscription_plans')
      .select('*')
      .eq('is_active', true)
      .order('price_iqd', { ascending: true });

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
};

export const initiateFibHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { planId } = fibCheckoutSchema.parse(req.body);
    const userId = req.user!.id;

    const result = await paymentService.initiateFibPayment(userId, planId);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
};

export const redeemVoucherHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { code } = redeemVoucherSchema.parse(req.body);
    const userId = req.user!.id;

    const result = await paymentService.redeemVoucher(userId, code);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
};

export const webhookHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const gateway = req.params.gateway;
    const handled = await paymentService.handlePaymentWebhook(gateway, req.body);
    res.json({ success: handled });
  } catch (err) {
    next(err);
  }
};
