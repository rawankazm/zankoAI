import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { AudioService } from './audio.service.js';
import { submitAudioJobSchema, audioJobIdParamSchema } from './validators/audio.validator.js';

// ─── Multer: in-memory storage (max 50 MB for lecture audio) ──────────────────
export const audioUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50 MB
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    const allowed = [
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
      'audio/x-wav',
      'audio/aac',
      'audio/ogg',
      'audio/webm',
      'audio/x-m4a',
      'audio/m4a',
    ];
    if (!allowed.includes(file.mimetype)) {
      return cb(
        new Error(`Invalid audio type: '${file.mimetype}'. Allowed types: MP3, WAV, M4A, AAC, OGG, WebM.`)
      );
    }
    cb(null, true);
  },
});

// ─── POST /api/ai/audio ───────────────────────────────────────────────────────

/**
 * Submit teacher lecture audio for async transcription, summarization, flashcard & quiz generation.
 * Responds immediately with 202 Accepted + jobId.
 */
export const submitAudioJobHandler = async (
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
          message: 'No audio file was uploaded. Send a multipart/form-data request with a "file" field.',
        },
      });
      return;
    }

    const validatedBody = submitAudioJobSchema.parse(req.body);
    const userId = req.user!.id;

    const rawKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
    const idempotencyKey =
      typeof rawKey === 'string' && rawKey.trim().length > 0 ? rawKey.trim() : undefined;

    const result = await AudioService.submitJob(userId, file, validatedBody, idempotencyKey);

    res.status(202).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── GET /api/ai/audio/:jobId ─────────────────────────────────────────────────

/**
 * Poll job status and fetch results. Course membership enforced.
 */
export const getAudioJobStatusHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = audioJobIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await AudioService.getJobStatus(jobId, userId);

    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// ─── DELETE /api/ai/audio/:jobId ──────────────────────────────────────────────

/**
 * Teacher deletion of their lecture recording.
 */
export const deleteAudioJobHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { jobId } = audioJobIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await AudioService.deleteJob(jobId, userId);

    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};
