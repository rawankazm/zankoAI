// ==============================================================================
// ZankoAI AI Homework Solver Controller
// ==============================================================================

import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { homeworkService } from './homework.service.js';
import { submitHomeworkSchema } from './validators/homework.validator.js';

export const homeworkUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB max image size
    files: 1,
  },
});

/**
 * POST /api/ai/homework
 * Handles student/teacher homework questions with educational step-by-step reasoning.
 */
export const submitHomeworkHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedBody = submitHomeworkSchema.parse(req.body);
    const userId = req.user!.id;
    const idempotencyKey = req.headers['idempotency-key'] as string | undefined;

    const result = await homeworkService.solveHomework(
      userId,
      validatedBody,
      req.file,
      idempotencyKey
    );

    res.status(200).json({
      success: true,
      data: result.solution,
      usage: result.usage,
    });
  } catch (err) {
    next(err);
  }
};
