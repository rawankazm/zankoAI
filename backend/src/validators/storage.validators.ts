import { z } from 'zod';

const STORAGE_CATEGORIES = [
  'avatars',
  'lecture-files',
  'pdfs',
  'ocr-images',
  'audio',
  'homework-images',
  'generated-files',
] as const;

// Safe path validation regex: letters, numbers, hyphens, underscores, dots, and forward slashes. No '..' or leading/trailing slashes.
const SAFE_PATH_REGEX = /^(?!.*\.\.)[a-zA-Z0-9_\-\.\/]+$/;

export const uploadTicketSchema = z.object({
  category: z.enum(STORAGE_CATEGORIES, {
    errorMap: () => ({ message: `Invalid storage category. Must be one of: ${STORAGE_CATEGORIES.join(', ')}` }),
  }),
  originalFileName: z.string().min(1, 'File name is required').max(255, 'File name too long'),
  fileSizeBytes: z.number().int().positive('File size must be a positive integer'),
  mimeType: z.string().min(1, 'MIME type is required').max(100),
  courseId: z.string().uuid('Invalid course ID format').optional(),
  lectureId: z.string().uuid('Invalid lecture ID format').optional(),
  assignmentId: z.string().uuid('Invalid assignment ID format').optional(),
});

export const signedUrlSchema = z.object({
  category: z.enum(STORAGE_CATEGORIES),
  storagePath: z
    .string()
    .min(1, 'Storage path is required')
    .max(500)
    .regex(SAFE_PATH_REGEX, 'Invalid storage path: Path traversal or disallowed characters detected'),
  expiresInSeconds: z
    .number()
    .int()
    .min(60, 'Minimum expiration is 60 seconds')
    .max(3600, 'Maximum expiration is 3600 seconds (1 hour)')
    .default(900),
});

export const deleteFileSchema = z.object({
  category: z.enum(STORAGE_CATEGORIES),
  storagePath: z
    .string()
    .min(1, 'Storage path is required')
    .max(500)
    .regex(SAFE_PATH_REGEX, 'Invalid storage path: Path traversal or disallowed characters detected'),
});
