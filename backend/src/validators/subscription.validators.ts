// ==============================================================================
// ZankoAI Subscription Request Validators (Zod)
// ==============================================================================

import { z } from 'zod';

export const checkoutSchema = z.object({
  plan: z.enum([
    'FREE',
    'PREMIUM_MONTHLY',
    'PREMIUM_YEARLY',
    'STUDENT',
    'UNIVERSITY',
    'TEAM',
  ]),
  provider: z.enum(['fib', 'fastpay', 'zaincash', 'qi_card', 'stripe', 'sandbox']),
  returnUrl: z.string().url().optional(),
  cancelUrl: z.string().url().optional(),
});

export const cancelSubscriptionSchema = z.object({
  reason: z.string().max(500).optional(),
});
