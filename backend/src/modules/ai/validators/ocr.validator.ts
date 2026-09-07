import { z } from 'zod';

// ─── Submit OCR Job Schema ───────────────────────────────────────────────────

export const submitOcrJobSchema = z.object({
  ocrType: z
    .enum(['auto', 'printed', 'handwriting'])
    .default('auto'),
  processingType: z
    .enum(['extract_only', 'all', 'summarize', 'quiz', 'flashcards', 'questions'])
    .default('all'),
});

export type SubmitOcrJobBody = z.infer<typeof submitOcrJobSchema>;

// ─── OCR Job ID Param Schema ─────────────────────────────────────────────────

export const ocrJobIdParamSchema = z.object({
  jobId: z
    .string()
    .uuid('jobId must be a valid UUID'),
});

export type OcrJobIdParam = z.infer<typeof ocrJobIdParamSchema>;
