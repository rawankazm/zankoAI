import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { enforceUsage } from '../../middleware/enforceUsage.js';
import { rateLimiter } from '../../middleware/rate_limiter.js';
import { uploadGuard } from '../../middleware/uploadGuard.js';
import {
  chatHandler,
  listConversationsHandler,
  getConversationHandler,
  deleteConversationHandler,
  solveImageHandler,
  generateQuizHandler,
  generateFlashcardsHandler,
} from './ai.controller.js';
import {
  pdfUpload,
  submitPdfJobHandler,
  getPdfJobStatusHandler,
  askPdfQuestionHandler,
} from './pdf.controller.js';
import {
  ocrUpload,
  submitOcrJobHandler,
  getOcrJobStatusHandler,
  deleteOcrJobHandler,
} from './ocr.controller.js';

const router = Router();

// ── 1. AI Chat (daily limit: free=10, premium=500) ────────────────────────────
router.post(
  '/chat',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 30, keyPrefix: 'rl:ai:chat' }),
  enforceUsage('ai_chat'),
  chatHandler
);

// ── 2. AI Conversations Management ───────────────────────────────────────────
router.get(
  '/conversations',
  authenticate,
  listConversationsHandler
);

router.get(
  '/conversations/:id',
  authenticate,
  getConversationHandler
);

router.delete(
  '/conversations/:id',
  authenticate,
  deleteConversationHandler
);

// ── 3. Homework / Image Solving (daily limit: free=10, premium=200) ───────────
router.post(
  '/solve-image',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 20, keyPrefix: 'rl:ai:solve' }),
  enforceUsage('homework'),
  solveImageHandler
);

// ── 4. Quiz Generation (monthly limit: free=5, premium=200) ──────────────────
router.post(
  '/generate-quiz',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:quiz' }),
  enforceUsage('quiz'),
  generateQuizHandler
);

// ── 5. Flashcards Generation (monthly limit: free=5, premium=200) ─────────────
router.post(
  '/generate-flashcards',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:flashcards' }),
  enforceUsage('flashcards'),
  generateFlashcardsHandler
);

// ── 6. PDF AI Processing ──────────────────────────────────────────────────────

/**
 * POST /api/ai/pdf
 * Submit a PDF for async AI processing (summarize, quiz, flashcards, questions).
 * - Quota: 'pdf' (monthly). Enforced inside PdfService.submitJob for idempotency safety.
 * - File: multipart/form-data, field name "file", max 30 MB.
 * - Header: Idempotency-Key (optional UUID) to safely retry on network errors.
 * - Response: 202 Accepted + { jobId, status: 'queued', ... }
 */
router.post(
  '/pdf',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 5, keyPrefix: 'rl:ai:pdf' }),
  pdfUpload.single('file'),
  uploadGuard({
    type: 'document',
    allowedMimes: ['application/pdf'],
    allowedExtensions: ['.pdf'],
    maxSizeBytes: 30 * 1024 * 1024,
  }),
  submitPdfJobHandler
);

/**
 * GET /api/ai/pdf/:jobId
 * Poll the processing status of a submitted PDF job.
 * Returns results when status === 'completed'.
 * No quota consumption — safe to poll every 3 seconds.
 */
router.get(
  '/pdf/:jobId',
  authenticate,
  getPdfJobStatusHandler
);

/**
 * POST /api/ai/pdf/:jobId/ask
 * Ask a question about a completed PDF using stored AI context.
 * Consumes ai_chat quota (not pdf quota).
 */
router.post(
  '/pdf/:jobId/ask',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 20, keyPrefix: 'rl:ai:pdf:ask' }),
  enforceUsage('ai_chat'),
  askPdfQuestionHandler
);

// ── 7. AI OCR Processing ──────────────────────────────────────────────────────

/**
 * POST /api/ai/ocr
 * Submit an image (handwritten or printed) for async OCR and AI processing.
 * - Quota: 'ocr' (monthly). Enforced server-side with idempotency protection.
 * - File: multipart/form-data, field name "file", max 10 MB.
 * - Header: Idempotency-Key (optional UUID).
 * - Response: 202 Accepted + { jobId, status: 'queued', ... }
 */
router.post(
  '/ocr',
  authenticate,
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 10, keyPrefix: 'rl:ai:ocr' }),
  ocrUpload.single('file'),
  uploadGuard({
    type: 'image',
    allowedMimes: ['image/jpeg', 'image/png', 'image/webp'],
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.webp'],
    maxSizeBytes: 10 * 1024 * 1024,
  }),
  submitOcrJobHandler
);

/**
 * GET /api/ai/ocr/:jobId
 * Poll the processing status of an OCR job.
 * Returns extracted text, detected type, and AI learning aids when completed.
 */
router.get(
  '/ocr/:jobId',
  authenticate,
  getOcrJobStatusHandler
);

/**
 * DELETE /api/ai/ocr/:jobId
 * Delete user's OCR job and permanently purge the image from private storage.
 */
router.delete(
  '/ocr/:jobId',
  authenticate,
  deleteOcrJobHandler
);

export const aiRoutes = router;

