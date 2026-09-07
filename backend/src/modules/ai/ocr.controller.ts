import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { OcrService } from './ocr.service.js';
import { submitOcrJobSchema, ocrJobIdParamSchema } from './validators/ocr.validator.js';

// ─── Multer: in-memory storage (max 10 MB for OCR images) ─────────────────────
export const ocrUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB hard limit
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowed.includes(file.mimetype)) {
      return cb(
        new Error(`Invalid image type: '${file.mimetype}'. Allowed types: ${allowed.join(', ')}`)
      );
    }
    cb(null, true);
  },
});

// ─── POST /api/ai/ocr ─────────────────────────────────────────────────────────

/**
 * Submit an image for async OCR & AI processing.
 * Responds immediately with 202 Accepted + jobId.
 */
export const submitOcrJobHandler = async (
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
          message: 'No image file was uploaded. Send a multipart/form-data request with a "file" field.',
        },
      });
      return;
    }

    const { ocrType, processingType } = submitOcrJobSchema.parse(req.body);
    const userId = req.user!.id;

    // Extract idempotency key from header
    const rawKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
    const idempotencyKey =
      typeof rawKey === 'string' && rawKey.trim().length > 0 ? rawKey.trim() : undefined;

    const result = await OcrService.submitJob(
      userId,
      file,
      ocrType,
      processingType,
      idempotencyKey
    );

    res.status(202).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── GET /api/ai/ocr/:jobId ───────────────────────────────────────────────────

/**
 * Poll OCR job status and fetch results when completed.
 */
export const getOcrJobStatusHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = ocrJobIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await OcrService.getJobStatus(jobId, userId);

    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── DELETE /api/ai/ocr/:jobId ────────────────────────────────────────────────

/**
 * User deletion of their OCR job and image.
 */
export const deleteOcrJobHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = ocrJobIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await OcrService.deleteJob(jobId, userId);

    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};
