import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { quotaGuard } from '../../middleware/quota_guard.js';
import { rateLimiter } from '../../middleware/rate_limiter.js';
import { chatHandler, solveImageHandler, generateQuizHandler } from './ai.controller.js';

const router = Router();

// Apply Auth, sliding window rate limit, and daily quota guard
router.post(
  '/chat',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 30, keyPrefix: 'rl:ai:chat' }),
  quotaGuard('ai_chat'),
  chatHandler
);

router.post(
  '/solve-image',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 20, keyPrefix: 'rl:ai:solve' }),
  quotaGuard('ai_solve'),
  solveImageHandler
);

router.post(
  '/generate-quiz',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:quiz' }),
  generateQuizHandler
);

export const aiRoutes = router;
