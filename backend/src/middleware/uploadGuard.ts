import { Request, Response, NextFunction } from 'express';
import path from 'path';
import crypto from 'crypto';
import { BadRequestError } from '../utils/apiError.js';
import { SecurityLogger } from '../utils/securityLogger.js';

export interface UploadGuardOptions {
  maxSizeBytes?: number;
  allowedMimes?: string[];
  allowedExtensions?: string[];
  type?: 'document' | 'image' | 'any';
}

const DEFAULT_DOC_EXTENSIONS = ['.pdf'];
const DEFAULT_IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp'];

const DEFAULT_DOC_MIMES = ['application/pdf'];
const DEFAULT_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

/**
 * Validates file buffer magic bytes to ensure the content matches its extension/MIME.
 */
export function validateMagicBytes(buffer: Buffer): { isValid: boolean; detectedType?: string } {
  if (!buffer || buffer.length < 4) {
    return { isValid: false };
  }

  // PDF: starts with %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
  if (
    buffer[0] === 0x25 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x44 &&
    buffer[3] === 0x46
  ) {
    return { isValid: true, detectedType: 'application/pdf' };
  }

  // JPEG: starts with 0xFF, 0xD8, 0xFF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { isValid: true, detectedType: 'image/jpeg' };
  }

  // PNG: starts with 0x89, 0x50, 0x4E, 0x47
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return { isValid: true, detectedType: 'image/png' };
  }

  // WebP: starts with "RIFF" and has "WEBP" at offset 8
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return { isValid: true, detectedType: 'image/webp' };
  }

  return { isValid: false };
}

/**
 * Sanitize filename against directory traversal, null bytes, and dangerous extensions
 */
export function sanitizeUploadedFilename(originalName: string): string {
  // Strip path separators and null bytes
  const baseName = path.basename(originalName).replace(/\0/g, '');
  const ext = path.extname(baseName).toLowerCase().replace(/[^a-z0-9.]/g, '');
  const randomPrefix = crypto.randomUUID();

  return `${randomPrefix}${ext}`;
}

/**
 * Upload Guard Middleware for multipart/file payload inspection
 */
export const uploadGuard = (options: UploadGuardOptions = {}) => {
  const isImage = options.type === 'image';
  const maxSize = options.maxSizeBytes || (isImage ? 5 * 1024 * 1024 : 15 * 1024 * 1024);
  const allowedExts =
    options.allowedExtensions ||
    (isImage ? DEFAULT_IMAGE_EXTENSIONS : [...DEFAULT_DOC_EXTENSIONS, ...DEFAULT_IMAGE_EXTENSIONS]);
  const allowedMimes =
    options.allowedMimes ||
    (isImage ? DEFAULT_IMAGE_MIMES : [...DEFAULT_DOC_MIMES, ...DEFAULT_IMAGE_MIMES]);

  return (req: Request, res: Response, next: NextFunction): void => {
    // Check if req has files (from multer or custom buffer parser)
    const file = (req as any).file;
    const files = (req as any).files;

    const fileList = file ? [file] : Array.isArray(files) ? files : [];

    for (const f of fileList) {
      // 1. File size check
      if (f.size && f.size > maxSize) {
        SecurityLogger.fromRequest(req, 'MALICIOUS_UPLOAD_BLOCKED', 'WARN', 'BLOCKED', {
          reason: `File size ${f.size} exceeds maximum limit ${maxSize}`,
          fileName: f.originalname,
        });
        return next(
          new BadRequestError(
            `File size exceeds maximum allowed limit of ${Math.round(maxSize / (1024 * 1024))}MB`
          )
        );
      }

      // 2. File extension check
      const ext = path.extname(f.originalname || '').toLowerCase();
      if (!allowedExts.includes(ext)) {
        SecurityLogger.fromRequest(req, 'MALICIOUS_UPLOAD_BLOCKED', 'WARN', 'BLOCKED', {
          reason: `Extension '${ext}' is not permitted`,
          fileName: f.originalname,
        });
        return next(
          new BadRequestError(
            `File extension '${ext}' is not permitted. Allowed: [${allowedExts.join(', ')}]`
          )
        );
      }

      // 3. MIME type check
      if (f.mimetype && !allowedMimes.includes(f.mimetype)) {
        SecurityLogger.fromRequest(req, 'MALICIOUS_UPLOAD_BLOCKED', 'WARN', 'BLOCKED', {
          reason: `MIME type '${f.mimetype}' is not permitted`,
          fileName: f.originalname,
        });
        return next(
          new BadRequestError(
            `MIME type '${f.mimetype}' is not allowed. Permitted types: [${allowedMimes.join(', ')}]`
          )
        );
      }

      // 4. Magic bytes verification (requires in-memory buffer)
      // SECURITY [H-08]: If buffer is absent (e.g. diskStorage), reject the upload.
      // Never allow unverified files through — always use multer memoryStorage for security-critical uploads.
      if (!f.buffer || !Buffer.isBuffer(f.buffer)) {
        SecurityLogger.fromRequest(req, 'MALICIOUS_UPLOAD_BLOCKED', 'CRITICAL', 'BLOCKED', {
          reason: 'File buffer unavailable for magic byte verification — possible diskStorage misconfiguration',
          fileName: f.originalname,
        });
        return next(
          new BadRequestError(
            'Security verification failed: File content could not be verified. Ensure multipart uploads use memory storage.'
          )
        );
      }

      const check = validateMagicBytes(f.buffer);
      if (!check.isValid) {
        SecurityLogger.fromRequest(req, 'MALICIOUS_UPLOAD_BLOCKED', 'CRITICAL', 'BLOCKED', {
          reason: 'File contents do not match genuine document/image magic bytes',
          fileName: f.originalname,
        });
        return next(
          new BadRequestError(
            'Security verification failed: File content does not match genuine document or image structure'
          )
        );
      }


      // 5. Sanitize filename on request object
      if (f.originalname) {
        f.sanitizedName = sanitizeUploadedFilename(f.originalname);
      }
    }

    next();
  };
};
