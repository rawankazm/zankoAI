// ==============================================================================
// ZankoAI Payment Request Validators (Zod)
// ==============================================================================

import { z } from 'zod';

export const createPaymentCheckoutSchema = z.object({
  plan: z.enum([
    'FREE',
    'PREMIUM_MONTHLY',
    'PREMIUM_YEARLY',
    'STUDENT',
    'UNIVERSITY',
    'TEAM',
  ]),
  provider: z.enum(['qi_card', 'zaincash', 'fastpay', 'fib', 'sandbox']).optional(),
  returnUrl: z.string().url().optional(),
  isRenewal: z.boolean().optional(),
});

export const refundPaymentSchema = z.object({
  reason: z.string().max(500).optional(),
  amount: z.number().positive().optional(),
});
