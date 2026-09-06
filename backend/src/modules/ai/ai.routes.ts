import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { enforceUsage } from '../../middleware/enforceUsage.js';
import { rateLimiter } from '../../middleware/rate_limiter.js';
import { chatHandler, solveImageHandler, generateQuizHandler, generateFlashcardsHandler } from './ai.controller.js';

const router = Router();

// 1. AI Chat (Enforce daily plan limit: free = 10, premium = 500 fair use)
router.post(
  '/chat',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 30, keyPrefix: 'rl:ai:chat' }),
  enforceUsage('ai_chat'),
  chatHandler
);

// 2. Homework & Image Solving (Enforce daily plan limit: free = 10, premium = 200 fair use)
router.post(
  '/solve-image',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 20, keyPrefix: 'rl:ai:solve' }),
  enforceUsage('homework'),
  solveImageHandler
);

// 3. Quiz Generation (Enforce monthly plan limit: free = 5, premium = 200 fair use)
router.post(
  '/generate-quiz',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:quiz' }),
  enforceUsage('quiz'),
  generateQuizHandler
);

// 4. Flashcards Generation (Enforce monthly plan limit: free = 5, premium = 200 fair use)
router.post(
  '/generate-flashcards',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:flashcards' }),
  enforceUsage('flashcards'),
  generateFlashcardsHandler
);

export const aiRoutes = router;

