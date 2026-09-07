// ==============================================================================
// ZankoAI Subscription API Routes
// ==============================================================================

import { Router } from 'express';
import { SubscriptionController } from '../controllers/subscription.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// GET /api/subscription - Get current user subscription status
router.get('/', authenticateUser, asyncWrapper(SubscriptionController.getSubscription));

// GET /api/subscription/history - Get subscription history, payment history, and event audit history
router.get('/history', authenticateUser, asyncWrapper(SubscriptionController.getHistory));

// POST /api/subscription/checkout - Initiate subscription checkout session
router.post('/checkout', authenticateUser, asyncWrapper(SubscriptionController.createCheckout));

// POST /api/subscription/cancel - Cancel recurring subscription at period end or immediately
router.post('/cancel', authenticateUser, asyncWrapper(SubscriptionController.cancelSubscription));

// POST /api/subscription/maintenance - Execute subscription maintenance routine on-demand
router.post('/maintenance', authenticateUser, asyncWrapper(SubscriptionController.runMaintenance));

// POST /api/subscription/restore - Server-side restore of subscription
router.post('/restore', authenticateUser, asyncWrapper(SubscriptionController.restoreSubscription));

// POST /api/subscription/webhook/:provider - Inbound provider payment webhook
router.post('/webhook/:provider', asyncWrapper(SubscriptionController.handleWebhook));

export const subscriptionRoutes = router;
