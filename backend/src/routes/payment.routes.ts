// ==============================================================================
// ZankoAI Payments API Routes
// ==============================================================================

import { Router } from 'express';
import { PaymentController } from '../controllers/payment.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// POST /api/payments/checkout - Initiates checkout with payment gateway
router.post('/checkout', authenticateUser, asyncWrapper(PaymentController.createCheckout));

// GET /api/payments/:id - Retrieves payment record and status
router.get('/:id', authenticateUser, asyncWrapper(PaymentController.getPayment));

// POST /api/payments/webhook/:provider - Inbound gateway webhook callback
router.post('/webhook/:provider', asyncWrapper(PaymentController.handleWebhook));

// POST /api/payments/:id/refund - Refunds captured payment
router.post('/:id/refund', authenticateUser, asyncWrapper(PaymentController.refundPayment));

export const paymentRoutes = router;
