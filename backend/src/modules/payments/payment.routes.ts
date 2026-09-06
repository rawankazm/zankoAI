import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { rateLimiter } from '../../middleware/rate_limiter.js';
import {
  getPlansHandler,
  initiateFibHandler,
  redeemVoucherHandler,
  webhookHandler,
} from './payment.controller.js';

const router = Router();

// Public: Get VIP Subscription Plans
router.get('/plans', getPlansHandler);

// Protected: Initiate FIB checkout
router.post(
  '/checkout/fib',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:pay:fib' }),
  initiateFibHandler
);

// Protected: Redeem prepaid scratch card voucher
router.post(
  '/redeem-voucher',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 5, keyPrefix: 'rl:pay:voucher' }),
  redeemVoucherHandler
);

// Public Webhook: Inbound callback from payment gateways
router.post('/webhook/:gateway', webhookHandler);

export const paymentRoutes = router;
