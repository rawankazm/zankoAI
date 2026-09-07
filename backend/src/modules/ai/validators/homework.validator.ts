// ==============================================================================
// ZankoAI AI Homework Solver Validator & Abuse Protection
// ==============================================================================

import { z } from 'zod';
import { BadRequestError } from '../../../utils/apiError.js';
import { getImageDimensions, type ImageDimensions } from '../../../utils/image_dimensions.js';

// Suspicious patterns indicating prompt injection or system override attempts
const PROMPT_INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?(previous|above)\s+instructions/i,
  /reveal\s+(the\s+)?(system\s+prompt|hidden\s+instructions)/i,
  /disregard\s+(all\s+)?(safety|rules|guidelines)/i,
  /bypass\s+(security|restrictions)/i,
  /you\s+are\s+now\s+in\s+developer\s+mode/i,
  /override\s+system\s+role/i,
];

/**
 * Checks for prompt injection and abuse payloads in student text.
 */
export function checkAbuseAndInjection(text?: string): void {
  if (!text) return;

  for (const pattern of PROMPT_INJECTION_PATTERNS) {
    if (pattern.test(text)) {
      throw new BadRequestError('داواکارییەکە ڕەتکرایەوە بەهۆی بوونی دەستەواژەی قەدەغەکراو (Prompt Injection detected).');
    }
  }
}

/**
 * Validates image buffer magic bytes and dimensions using zero-dependency binary parsing.
 */
export function validateHomeworkImage(buffer: Buffer): ImageDimensions {
  if (!buffer || buffer.length === 0) {
    throw new BadRequestError('فایلی وێنەکە بەتاڵە.');
  }

  // Max 10MB
  if (buffer.length > 10 * 1024 * 1024) {
    throw new BadRequestError('قەبارەی وێنە ناتوانێت لە ١٠ مێگابایت زیاتر بێت.');
  }

  try {
    const dimensions = getImageDimensions(buffer);

    // Dimension bounds check (defend against pixel flood / decompression bombs)
    if (dimensions.width > 10000 || dimensions.height > 10000) {
      throw new BadRequestError('پانتایی یان درێژیی وێنەکە لە سنوری ڕێگەپێدراو زیاترە (زۆرینە ١٠,٠٠٠ پیکسڵ).');
    }

    if (dimensions.width < 10 || dimensions.height < 10) {
      throw new BadRequestError('وێنەکە زۆر بچووکە و ڕوون نییە.');
    }

    return dimensions;
  } catch (err: any) {
    throw new BadRequestError(`فایلی وێنەکە نادروستە یان تێکچووە: ${err.message}`);
  }
}

// ─── Zod Body Schema ──────────────────────────────────────────────────────────

export const submitHomeworkSchema = z.object({
  text: z
    .string()
    .trim()
    .max(5000, 'دەقی پرسیار ناتوانێت لە ٥,٠٠٠ پیت زیاتر بێت.')
    .optional(),
  subject: z
    .string()
    .trim()
    .min(1, 'تکایە بابەتی زانستی پرسیارەکە دیاریبکە.')
    .max(100, 'ناوی بابەت زۆر درێژە.'),
  course: z
    .string()
    .trim()
    .max(120, 'ناوی کۆرس ناتوانێت لە ١٢٠ پیت زیاتر بێت.')
    .optional(),
  difficulty: z
    .enum(['easy', 'medium', 'hard', 'advanced'])
    .default('medium'),
  language: z
    .string()
    .trim()
    .default('ku'),
});

export type SubmitHomeworkBody = z.infer<typeof submitHomeworkSchema>;
