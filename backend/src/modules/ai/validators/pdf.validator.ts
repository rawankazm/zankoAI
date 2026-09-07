import { z } from 'zod';

// ─── Submit PDF Job ───────────────────────────────────────────────────────────

export const submitPdfJobSchema = z.object({
  processingType: z
    .enum(['all', 'summarize', 'quiz', 'flashcards', 'questions'])
    .default('all'),
});

export type SubmitPdfJobBody = z.infer<typeof submitPdfJobSchema>;

// ─── Get Job Status ───────────────────────────────────────────────────────────

export const pdfJobIdParamSchema = z.object({
  jobId: z
    .string()
    .uuid('jobId must be a valid UUID'),
});

export type PdfJobIdParam = z.infer<typeof pdfJobIdParamSchema>;

// ─── Ask Question about PDF ───────────────────────────────────────────────────

export const askPdfSchema = z.object({
  question: z
    .string()
    .min(3, 'Question must be at least 3 characters')
    .max(2000, 'Question must not exceed 2000 characters')
    .trim(),
});

export type AskPdfBody = z.infer<typeof askPdfSchema>;
