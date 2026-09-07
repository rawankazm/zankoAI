import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { PdfService } from './pdf.service.js';
import {
  submitPdfJobSchema,
  pdfJobIdParamSchema,
  askPdfSchema,
} from './validators/pdf.validator.js';

// ─── Multer: in-memory storage (max 30 MB) ────────────────────────────────────
export const pdfUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 30 * 1024 * 1024, // 30 MB hard cap
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    // Pre-filter by MIME before uploadGuard does the thorough magic bytes check
    if (file.mimetype !== 'application/pdf') {
      return cb(new Error(`Invalid file type: '${file.mimetype}'. Only application/pdf is allowed.`));
    }
    cb(null, true);
  },
});

// ─── POST /api/ai/pdf ─────────────────────────────────────────────────────────

/**
 * Submit a PDF for AI processing.
 * Responds immediately with 202 Accepted + jobId.
 * The actual processing happens asynchronously via BullMQ.
 */
export const submitPdfJobHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const file = (req as any).file as Express.Multer.File | undefined;

    if (!file) {
      res.status(400).json({
        success: false,
        error: {
          code: 'MISSING_FILE',
          message: 'No PDF file was uploaded. Send a multipart/form-data request with a "file" field.',
        },
      });
      return;
    }

    const { processingType } = submitPdfJobSchema.parse(req.body);
    const userId = req.user!.id;

    // Extract idempotency key from standard header
    const rawKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
    const idempotencyKey = typeof rawKey === 'string' && rawKey.trim().length > 0
      ? rawKey.trim()
      : undefined;

    const result = await PdfService.submitJob(userId, file, processingType, idempotencyKey);

    // 202 Accepted — processing is async
    res.status(202).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── GET /api/ai/pdf/:jobId ───────────────────────────────────────────────────

/**
 * Poll job status and retrieve results when completed.
 * Safe to poll frequently — no quota is consumed.
 */
export const getPdfJobStatusHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = pdfJobIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await PdfService.getJobStatus(jobId, userId);

    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── POST /api/ai/pdf/:jobId/ask ──────────────────────────────────────────────

/**
 * Ask a question about a completed PDF.
 * Consumes ai_chat quota (enforced via middleware in routes).
 */
export const askPdfQuestionHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = pdfJobIdParamSchema.parse(req.params);
    const { question } = askPdfSchema.parse(req.body);
    const userId = req.user!.id;

    const answer = await PdfService.askQuestion(jobId, userId, question);

    res.json({
      success: true,
      data: {
        jobId,
        answer,
      },
      usage: req.usageInfo
        ? {
            current_usage: req.usageInfo.current_usage,
            limit: req.usageInfo.limit,
            remaining: req.usageInfo.remaining,
            reset_at: req.usageInfo.reset_at,
          }
        : undefined,
    });
  } catch (err) {
    next(err);
  }
};
