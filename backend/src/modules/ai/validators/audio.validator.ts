import { z } from 'zod';

// ─── Submit Audio Job Schema ──────────────────────────────────────────────────

export const submitAudioJobSchema = z.object({
  courseId: z
    .string()
    .uuid('courseId must be a valid UUID'),
  title: z
    .string()
    .min(2, 'Title must be at least 2 characters')
    .max(200, 'Title must not exceed 200 characters')
    .trim(),
  lectureId: z
    .string()
    .uuid('lectureId must be a valid UUID')
    .optional(),
  language: z
    .string()
    .max(10)
    .default('ku'),
  durationSeconds: z
    .coerce
    .number()
    .int()
    .min(0)
    .max(18000) // max 5 hours
    .default(0),
});

export type SubmitAudioJobBody = z.infer<typeof submitAudioJobSchema>;

// ─── Audio Job ID Param Schema ────────────────────────────────────────────────

export const audioJobIdParamSchema = z.object({
  jobId: z
    .string()
    .uuid('jobId must be a valid UUID'),
});

export type AudioJobIdParam = z.infer<typeof audioJobIdParamSchema>;
