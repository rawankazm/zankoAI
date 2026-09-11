import { Router } from 'express';
import { authenticate } from '../../../middleware/authenticate.js';
import { enforceUsage } from '../../../middleware/enforceUsage.js';
import { rateLimiter } from '../../../middleware/rate_limiter.js';
import { aiCostGuard } from '../../../middleware/aiCostGuard.js';
import { AiTeacherController } from './ai_teacher.controller.js';

const router = Router();

// 1. AI Teacher Multilingual Academic Chat
router.post(
  '/chat',
  authenticate,
  aiCostGuard,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 40, keyPrefix: 'rl:ai-teacher:chat' }),
  enforceUsage('ai_chat'),
  AiTeacherController.chat
);

// 2. Single Chunk Voice Synthesis
router.post(
  '/tts',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 60, keyPrefix: 'rl:ai-teacher:tts' }),
  enforceUsage('audio'),
  AiTeacherController.synthesize
);

// 3. Batch Speech Synthesis for Long AI Responses
router.post(
  '/tts/batch',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 30, keyPrefix: 'rl:ai-teacher:tts-batch' }),
  enforceUsage('audio'),
  AiTeacherController.synthesizeBatch
);

// 4. Retry Failed Speech Chunk
router.post(
  '/tts/retry',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 60, keyPrefix: 'rl:ai-teacher:tts-retry' }),
  AiTeacherController.retryChunk
);

// 5. Available Academic Voices List
router.get(
  '/voices',
  authenticate,
  AiTeacherController.getVoices
);

// 6. Voice Synthesis Health & Provider Status
router.get(
  '/voice-status',
  authenticate,
  AiTeacherController.getVoiceStatus
);

export { router as aiTeacherRoutes };
