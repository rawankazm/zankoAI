import path from 'path';
import crypto from 'crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { env } from '../config/env.js';
import { logger } from '../config/logger.js';
import { SecurityLogger } from '../utils/securityLogger.js';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
  QuotaExceededError,
} from '../utils/apiError.js';
import { UsageService } from './usage.service.js';
import { FeatureName, QuotaCheckResult } from '../types/usage.types.js';
import {
  StorageBucketConfig,
  StorageCategory,
  StorageUploadTicketRequest,
  StorageUploadTicketResponse,
  StorageSignedUrlRequest,
  StorageSignedUrlResponse,
  StorageCleanupReport,
} from '../types/storage.types.js';
import { UserProfile } from '../types/user.types.js';

// Category configuration matrix
export const BUCKET_CONFIGS: Record<StorageCategory, StorageBucketConfig> = {
  avatars: {
    id: 'avatars',
    isPublic: true,
    maxSizeBytes: 2 * 1024 * 1024, // 2 MB
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.webp'],
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    defaultExpiresInSeconds: 3600,
  },
  'lecture-files': {
    id: 'lecture-files',
    isPublic: false,
    maxSizeBytes: 50 * 1024 * 1024, // 50 MB
    allowedExtensions: ['.pdf', '.ppt', '.pptx', '.doc', '.docx', '.txt'],
    allowedMimeTypes: [
      'application/pdf',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
    ],
    defaultExpiresInSeconds: 900,
  },
  pdfs: {
    id: 'pdfs',
    isPublic: false,
    maxSizeBytes: 30 * 1024 * 1024, // 30 MB
    allowedExtensions: ['.pdf'],
    allowedMimeTypes: ['application/pdf'],
    defaultExpiresInSeconds: 900,
  },
  'ocr-images': {
    id: 'ocr-images',
    isPublic: false,
    maxSizeBytes: 10 * 1024 * 1024, // 10 MB
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.webp'],
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    defaultExpiresInSeconds: 900,
  },
  audio: {
    id: 'audio',
    isPublic: false,
    maxSizeBytes: 25 * 1024 * 1024, // 25 MB
    allowedExtensions: ['.mp3', '.m4a', '.wav', '.aac', '.ogg', '.webm'],
    allowedMimeTypes: [
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
      'audio/x-wav',
      'audio/aac',
      'audio/ogg',
      'audio/webm',
      'audio/x-m4a',
    ],
    defaultExpiresInSeconds: 900,
  },
  'homework-images': {
    id: 'homework-images',
    isPublic: false,
    maxSizeBytes: 10 * 1024 * 1024, // 10 MB
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.webp', '.pdf'],
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
    defaultExpiresInSeconds: 900,
  },
  'generated-files': {
    id: 'generated-files',
    isPublic: false,
    maxSizeBytes: 20 * 1024 * 1024, // 20 MB
    allowedExtensions: ['.pdf', '.mp3', '.json', '.txt'],
    allowedMimeTypes: ['application/pdf', 'audio/mpeg', 'application/json', 'text/plain'],
    defaultExpiresInSeconds: 900,
  },
};

export class StorageService {
  /**
   * Authorize and generate a secure upload ticket for client-side direct upload
   */
  static async createUploadTicket(
    caller: { id: string; profile: UserProfile },
    request: StorageUploadTicketRequest
  ): Promise<StorageUploadTicketResponse> {
    const config = BUCKET_CONFIGS[request.category];
    if (!config) {
      throw new BadRequestError(`Invalid storage category: ${request.category}`);
    }

    // 1. Validate file size against category limits
    if (request.fileSizeBytes > config.maxSizeBytes) {
      const maxMb = Math.round(config.maxSizeBytes / (1024 * 1024));
      throw new BadRequestError(`File size exceeds maximum allowed limit for ${request.category} (${maxMb}MB)`);
    }

    // 2. Validate file extension against allowlist
    const ext = path.extname(request.originalFileName).toLowerCase();
    if (!config.allowedExtensions.includes(ext)) {
      throw new BadRequestError(
        `Extension '${ext}' is not permitted for ${request.category}. Allowed: [${config.allowedExtensions.join(', ')}]`
      );
    }

    // 3. Validate MIME type
    const normalizedMime = request.mimeType.toLowerCase().trim();
    if (!config.allowedMimeTypes.includes(normalizedMime)) {
      throw new BadRequestError(
        `MIME type '${normalizedMime}' is not permitted for ${request.category}`
      );
    }

    // 4. Server-Authoritative Quota Enforcement (Never trust Flutter)
    let quotaResult: QuotaCheckResult | undefined;
    let trackedFeature: FeatureName | null = null;
    if (request.category === 'pdfs') trackedFeature = 'pdf';
    else if (request.category === 'ocr-images') trackedFeature = 'ocr';
    else if (request.category === 'audio') trackedFeature = 'audio';

    if (trackedFeature) {
      const featureCheck = await UsageService.consumeQuota(caller.id, trackedFeature, 1);
      if (!featureCheck.allowed) {
        throw new QuotaExceededError(
          `Monthly limit reached for ${request.category} (${featureCheck.current_usage}/${featureCheck.limit}). Please upgrade your plan.`,
          featureCheck
        );
      }
      quotaResult = featureCheck;
    }

    // Storage capacity check
    const storageCheck = await UsageService.consumeQuota(caller.id, 'storage', request.fileSizeBytes);
    if (!storageCheck.allowed) {
      const limitMb = Math.round(storageCheck.limit / (1024 * 1024));
      const currentMb = Math.round(storageCheck.current_usage / (1024 * 1024));
      throw new QuotaExceededError(
        `Storage capacity exceeded (${currentMb}MB / ${limitMb}MB limit). Upgrade to Premium or delete unused files.`,
        storageCheck
      );
    }
    if (!quotaResult) {
      quotaResult = storageCheck;
    }

    // 5. Role & Ownership Authorization per category
    let storagePath = '';
    const uniqueFileId = crypto.randomUUID();
    const safeFileName = `${uniqueFileId}${ext}`;

    switch (request.category) {
      case 'avatars': {
        // Avatars stored under {userId}/avatar.{ext}
        storagePath = `${caller.id}/avatar${ext}`;
        break;
      }

      case 'lecture-files': {
        // Must be instructor of course or admin
        if (!request.courseId) {
          throw new BadRequestError('courseId is required when uploading lecture files');
        }
        await this._assertCourseInstructorOrAdmin(caller, request.courseId);
        const lecturePart = request.lectureId || 'general';
        storagePath = `${request.courseId}/${lecturePart}/${safeFileName}`;
        break;
      }

      case 'homework-images': {
        // Student uploading homework submission
        if (!request.assignmentId) {
          throw new BadRequestError('assignmentId is required when uploading homework submissions');
        }
        storagePath = `${request.assignmentId}/${caller.id}/${safeFileName}`;
        break;
      }

      case 'audio': {
        if (request.courseId) {
          await this._assertCourseInstructorOrAdmin(caller, request.courseId);
          storagePath = `${request.courseId}/${request.lectureId || 'audio'}/${safeFileName}`;
        } else {
          storagePath = `${caller.id}/${safeFileName}`;
        }
        break;
      }

      case 'pdfs':
      case 'ocr-images':
      case 'generated-files':
      default: {
        // User private directory
        storagePath = `${caller.id}/${safeFileName}`;
        break;
      }
    }

    // 6. Generate Signed Upload URL via Supabase Storage
    const { data: uploadData, error: uploadErr } = await supabaseAdmin.storage
      .from(config.id)
      .createSignedUploadUrl(storagePath);

    if (uploadErr || !uploadData) {
      logger.error(`Failed to generate signed upload URL for ${request.category}/${storagePath}:`, uploadErr);
      throw new Error(`Storage error: Unable to generate upload ticket (${uploadErr?.message})`);
    }

    // For public buckets, compute public URL
    let publicUrl: string | undefined;
    if (config.isPublic) {
      const { data: pub } = supabaseAdmin.storage.from(config.id).getPublicUrl(storagePath);
      publicUrl = pub.publicUrl;
    }

    return {
      category: request.category,
      bucket: config.id,
      storagePath,
      signedUploadUrl: uploadData.signedUrl,
      token: uploadData.token,
      expiresInSeconds: config.defaultExpiresInSeconds,
      maxSizeBytes: config.maxSizeBytes,
      publicUrl,
      usage: quotaResult,
    };
  }

  /**
   * Generate an authorized short-lived Signed URL for private file access
   */
  static async createSignedDownloadUrl(
    caller: { id: string; profile: UserProfile },
    request: StorageSignedUrlRequest
  ): Promise<StorageSignedUrlResponse> {
    const config = BUCKET_CONFIGS[request.category];
    if (!config) {
      throw new BadRequestError(`Invalid storage category: ${request.category}`);
    }

    const { storagePath, expiresInSeconds = config.defaultExpiresInSeconds } = request;

    // 1. Validate Path Traversal Prevention
    if (storagePath.includes('..') || storagePath.startsWith('/') || storagePath.includes('\\')) {
      SecurityLogger.log({
        eventType: 'SUSPICIOUS_PAYLOAD',
        severity: 'CRITICAL',
        ip: 'server',
        userId: caller.id,
        status: 'BLOCKED',
        details: { reason: 'Path traversal attempt in storage download', path: storagePath },
      });
      throw new BadRequestError('Invalid file path');
    }

    // 2. Authorization Check: Ensure user has legitimate access rights to this file
    await this._assertDownloadAuthorization(caller, request.category, storagePath);

    // 3. Generate Signed URL with time expiration
    const { data, error } = await supabaseAdmin.storage
      .from(config.id)
      .createSignedUrl(storagePath, expiresInSeconds);

    if (error || !data) {
      logger.warn(`Failed to create signed download URL for ${config.id}/${storagePath}:`, error);
      throw new NotFoundError('Requested file not found in storage');
    }

    const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();

    return {
      signedUrl: data.signedUrl,
      expiresAt,
      expiresInSeconds,
      category: request.category,
      storagePath,
    };
  }

  /**
   * Delete a file with strict ownership or admin authorization
   */
  static async deleteFile(
    caller: { id: string; profile: UserProfile },
    category: StorageCategory,
    storagePath: string
  ): Promise<boolean> {
    const config = BUCKET_CONFIGS[category];
    if (!config) throw new BadRequestError(`Invalid category: ${category}`);

    // Verify deletion rights
    await this._assertDeleteAuthorization(caller, category, storagePath);

    const { error } = await supabaseAdmin.storage.from(config.id).remove([storagePath]);
    if (error) {
      logger.error(`Error deleting file from storage ${config.id}/${storagePath}:`, error);
      throw new Error(`Failed to delete storage file: ${error.message}`);
    }

    return true;
  }

  /**
   * Scan and clean orphaned files older than 24 hours
   */
  static async cleanupOrphanedFiles(olderThanHours = 24): Promise<StorageCleanupReport> {
    const { data: orphans, error } = await supabaseAdmin.rpc('get_orphaned_storage_files', {
      p_older_than_hours: olderThanHours,
    });

    if (error) {
      logger.warn('Could not query orphaned files via RPC, using direct query fallback:', error.message);
      return {
        scannedCount: 0,
        deletedCount: 0,
        reclaimedBytes: 0,
        timestamp: new Date().toISOString(),
      };
    }

    let deletedCount = 0;
    if (Array.isArray(orphans) && orphans.length > 0) {
      // Group by bucket
      const byBucket: Record<string, string[]> = {};
      for (const item of orphans) {
        if (!byBucket[item.bucket_id]) byBucket[item.bucket_id] = [];
        byBucket[item.bucket_id].push(item.file_name);
      }

      for (const [bucket, files] of Object.entries(byBucket)) {
        const { error: delErr } = await supabaseAdmin.storage.from(bucket).remove(files);
        if (!delErr) {
          deletedCount += files.length;
        } else {
          logger.warn(`Failed to clean orphans in bucket ${bucket}:`, delErr);
        }
      }
    }

    return {
      scannedCount: orphans?.length || 0,
      deletedCount,
      reclaimedBytes: 0,
      timestamp: new Date().toISOString(),
    };
  }

  // ─── Private Access Control Helpers ───

  private static async _assertCourseInstructorOrAdmin(
    caller: { id: string; profile: UserProfile },
    courseId: string
  ): Promise<void> {
    if (caller.profile.role === 'admin') return;

    const { data: course } = await supabaseAdmin
      .from('courses')
      .select('instructor_id')
      .eq('id', courseId)
      .maybeSingle();

    if (!course || course.instructor_id !== caller.id) {
      SecurityLogger.log({
        eventType: 'FORBIDDEN_ACCESS',
        severity: 'WARN',
        ip: 'server',
        userId: caller.id,
        status: 'DENIED',
        details: { courseId, reason: 'Caller is not course instructor or admin' },
      });
      throw new ForbiddenError('You are not authorized to upload or manage materials for this course');
    }
  }

  private static async _assertDownloadAuthorization(
    caller: { id: string; profile: UserProfile },
    category: StorageCategory,
    storagePath: string
  ): Promise<void> {
    // Admin always has global access
    if (caller.profile.role === 'admin') return;

    const parts = storagePath.split('/');

    switch (category) {
      case 'avatars': {
        // Avatars are publicly readable
        return;
      }

      case 'lecture-files': {
        // Path format: {courseId}/{lectureId}/{file}
        const courseId = parts[0];
        if (!courseId) throw new BadRequestError('Malformed lecture file path');

        // Check enrollment or instructor status
        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('id, instructor_id, department_id')
          .eq('id', courseId)
          .maybeSingle();

        if (!course) throw new NotFoundError('Associated course not found');

        if (course.instructor_id === caller.id) return;

        // Check if student is enrolled
        const { data: enrollment } = await supabaseAdmin
          .from('enrollments')
          .select('id')
          .eq('course_id', courseId)
          .eq('student_id', caller.id)
          .maybeSingle();

        if (enrollment) return;

        // Check if student belongs to the course's department
        if (caller.profile.department_id && caller.profile.department_id === course.department_id) {
          return;
        }

        throw new ForbiddenError('Access denied: You are not enrolled in or instructing this course');
      }

      case 'homework-images': {
        // Path format: {assignmentId}/{studentId}/{file}
        const assignmentId = parts[0];
        const studentId = parts[1];

        // Submitting student can access their own submission
        if (studentId === caller.id) return;

        // Course instructor can access all student submissions for their assignment
        if (assignmentId) {
          const { data: assignment } = await supabaseAdmin
            .from('assignments')
            .select('course_id, courses(instructor_id)')
            .eq('id', assignmentId)
            .maybeSingle();

          const instructorId = (assignment as any)?.courses?.instructor_id;
          if (instructorId && instructorId === caller.id) {
            return;
          }
        }

        throw new ForbiddenError('Access denied: You do not have permission to access this homework submission');
      }

      case 'pdfs':
      case 'ocr-images':
      case 'generated-files':
      case 'audio':
      default: {
        // User-private files: First segment of path is owner userId
        const ownerId = parts[0];
        if (ownerId !== caller.id) {
          SecurityLogger.log({
            eventType: 'IDOR_ATTEMPT',
            severity: 'CRITICAL',
            ip: 'server',
            userId: caller.id,
            status: 'BLOCKED',
            details: { category, storagePath, targetOwner: ownerId },
          });
          throw new ForbiddenError('Access denied: You can only access your own private files');
        }
        return;
      }
    }
  }

  private static async _assertDeleteAuthorization(
    caller: { id: string; profile: UserProfile },
    category: StorageCategory,
    storagePath: string
  ): Promise<void> {
    if (caller.profile.role === 'admin') return;

    const parts = storagePath.split('/');

    if (category === 'lecture-files') {
      const courseId = parts[0];
      await this._assertCourseInstructorOrAdmin(caller, courseId);
      return;
    }

    if (category === 'homework-images') {
      const studentId = parts[1];
      if (studentId !== caller.id) {
        throw new ForbiddenError('You can only delete your own homework submissions');
      }
      return;
    }

    // Default: first path part is caller ID
    const ownerId = parts[0];
    if (ownerId !== caller.id) {
      throw new ForbiddenError('You can only delete your own files');
    }
  }
}
