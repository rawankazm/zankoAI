import crypto from 'crypto';
import path from 'path';
import { supabaseAdmin } from '../../config/supabase.js';
import { logger } from '../../config/logger.js';
import { redis } from '../../config/redis.js';
import { SecurityLogger } from '../../utils/securityLogger.js';
import { validateMagicBytes } from '../../middleware/uploadGuard.js';
import { getImageDimensions, validateImageDimensions } from '../../utils/image_dimensions.js';
import { ocrAiQueue } from '../../jobs/queues.js';
import { UsageService } from '../../services/usage.service.js';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
  QuotaExceededError,
} from '../../utils/apiError.js';
import {
  OcrJob,
  OcrJobStatusResponse,
  OcrType,
  OcrProcessingType,
  OcrAiJobData,
} from '../../types/ocr.types.js';

/** Signed URL TTL for internal worker downloads (seconds) */
const INTERNAL_SIGNED_URL_TTL = 900; // 15 minutes

/** Idempotency key Redis TTL (seconds) */
const IDEMPOTENCY_TTL = 86400; // 24 hours

export class OcrService {
  // ─── Submit Job ────────────────────────────────────────────────────────────

  /**
   * Validate, upload, and enqueue an image for OCR processing.
   * Idempotency: duplicate requests with same key return the existing job without re-charging.
   */
  static async submitJob(
    userId: string,
    file: Express.Multer.File,
    ocrType: OcrType = 'auto',
    processingType: OcrProcessingType = 'all',
    idempotencyKey?: string
  ): Promise<OcrJobStatusResponse> {
    // 1. Derive idempotency key (caller-supplied or hash of content)
    const idemKey =
      idempotencyKey?.trim() ||
      crypto
        .createHash('sha256')
        .update(`${userId}:${file.originalname}:${file.size}`)
        .digest('hex');

    // 2. Idempotency check in Redis
    const redisKey = `ocr:idempotency:${userId}:${idemKey}`;
    const existingJobId = await redis.get(redisKey);
    if (existingJobId) {
      logger.info(`[OcrService] Idempotent replay for job ${existingJobId} (user ${userId})`);
      return this.getJobStatus(existingJobId, userId, true);
    }

    // 3. Server-authoritative quota enforcement (before storage write)
    const quotaResult = await UsageService.consumeQuota(userId, 'ocr', 1, idemKey);
    if (!quotaResult.allowed) {
      throw new QuotaExceededError(
        `Monthly OCR processing limit reached (${quotaResult.current_usage}/${quotaResult.limit}). Please upgrade your plan.`,
        quotaResult
      );
    }

    // 4. Re-validate magic bytes on in-memory buffer
    if (!file.buffer || !Buffer.isBuffer(file.buffer)) {
      throw new BadRequestError('File buffer is missing. Upload must include image content.');
    }

    const magicCheck = validateMagicBytes(file.buffer);
    if (!magicCheck.isValid || !magicCheck.detectedType?.startsWith('image/')) {
      SecurityLogger.log('MALICIOUS_UPLOAD_BLOCKED', 'CRITICAL', 'BLOCKED', {
        userId,
        reason: 'Magic bytes do not match supported image format',
        filename: file.originalname,
      });
      throw new BadRequestError(
        'Security check failed: File content does not match a genuine JPEG, PNG, or WebP image.'
      );
    }

    // 5. Dimension check & anti-decompression bomb protection
    let width = 0;
    let height = 0;
    try {
      const dimensions = getImageDimensions(file.buffer);
      validateImageDimensions(dimensions);
      width = dimensions.width;
      height = dimensions.height;
    } catch (dimErr: any) {
      throw new BadRequestError(`Image dimension validation failed: ${dimErr.message}`);
    }

    // 6. Upload buffer to Supabase Storage (ocr-images bucket)
    const uniqueId = crypto.randomUUID();
    const ext = path.extname(file.originalname).toLowerCase() || (magicCheck.detectedType === 'image/png' ? '.png' : magicCheck.detectedType === 'image/webp' ? '.webp' : '.jpg');
    const storagePath = `${userId}/${uniqueId}${ext}`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from('ocr-images')
      .upload(storagePath, file.buffer, {
        contentType: magicCheck.detectedType,
        upsert: false,
      });

    if (uploadError) {
      logger.error(`[OcrService] Storage upload failed for user ${userId}: ${uploadError.message}`);
      throw new Error(`Storage upload failed: ${uploadError.message}`);
    }

    // 7. Insert job record into ocr_jobs
    const { data: jobRow, error: dbError } = await supabaseAdmin
      .from('ocr_jobs')
      .insert({
        user_id: userId,
        idempotency_key: idemKey,
        original_filename: file.originalname,
        storage_path: storagePath,
        file_size_bytes: file.size,
        image_width: width,
        image_height: height,
        ocr_type: ocrType,
        processing_type: processingType,
        status: 'queued',
      })
      .select('*')
      .single();

    if (dbError || !jobRow) {
      // Clean up orphaned storage file if DB write fails
      await supabaseAdmin.storage.from('ocr-images').remove([storagePath]);
      logger.error(`[OcrService] Failed to insert ocr_jobs row: ${dbError?.message}`);
      throw new Error(`Database record creation failed: ${dbError?.message}`);
    }

    const job = jobRow as OcrJob;

    // 8. Cache idempotency key in Redis
    await redis.set(redisKey, job.id, 'EX', IDEMPOTENCY_TTL);

    // 9. Enqueue job into BullMQ
    const queueData: OcrAiJobData = {
      jobId: job.id,
      userId,
      storagePath,
      originalFilename: file.originalname,
      ocrType,
      processingType,
      imageWidth: width,
      imageHeight: height,
      fileSizeBytes: file.size,
    };

    const bullmqJob = await ocrAiQueue.add('process-ocr', queueData, {
      jobId: job.id,
      priority: 1,
    });

    // Update job with BullMQ ID
    await supabaseAdmin
      .from('ocr_jobs')
      .update({ bullmq_job_id: bullmqJob.id })
      .eq('id', job.id);

    logger.info(`[OcrService] Job ${job.id} enqueued to BullMQ (user ${userId})`);

    return this.buildResponseDto(job);
  }

  // ─── Get Job Status ─────────────────────────────────────────────────────────

  /**
   * Poll job status and fetch results when completed.
   * Safe to call repeatedly — no quota is consumed.
   */
  static async getJobStatus(
    jobId: string,
    userId: string,
    _isReplay = false
  ): Promise<OcrJobStatusResponse> {
    const { data: jobRow, error: jobError } = await supabaseAdmin
      .from('ocr_jobs')
      .select('*')
      .eq('id', jobId)
      .maybeSingle();

    if (jobError) {
      logger.error(`[OcrService] Error fetching job ${jobId}: ${jobError.message}`);
      throw new Error(`Failed to fetch OCR job: ${jobError.message}`);
    }

    if (!jobRow) {
      throw new NotFoundError(`OCR job with ID '${jobId}' was not found.`);
    }

    const job = jobRow as OcrJob;

    // Strict ownership enforcement
    if (job.user_id !== userId) {
      SecurityLogger.log('FORBIDDEN_ACCESS', 'WARN', 'BLOCKED', {
        userId,
        targetJobId: jobId,
        jobOwnerId: job.user_id,
      });
      throw new ForbiddenError('You do not have permission to view this OCR job.');
    }

    // If completed, fetch results
    let result: any = null;
    if (job.status === 'completed') {
      const { data: resRow } = await supabaseAdmin
        .from('ocr_job_results')
        .select('*')
        .eq('job_id', jobId)
        .maybeSingle();

      if (resRow) {
        result = {
          extractedText: resRow.extracted_text,
          detectedTextType: resRow.detected_text_type,
          confidenceScore: parseFloat(resRow.confidence_score) || 0.95,
          extractedTextLength: resRow.extracted_text_length,
          summary: resRow.summary,
          questions: resRow.questions,
          quiz: resRow.quiz,
          flashcards: resRow.flashcards,
          ocrProvider: resRow.ocr_provider,
        };
      }
    }

    return this.buildResponseDto(job, result);
  }

  // ─── Delete Job ─────────────────────────────────────────────────────────────

  /**
   * Delete an OCR job and purge its image from Supabase Storage.
   */
  static async deleteJob(
    jobId: string,
    userId: string
  ): Promise<{ success: boolean; message: string }> {
    const { data: jobRow, error: jobError } = await supabaseAdmin
      .from('ocr_jobs')
      .select('*')
      .eq('id', jobId)
      .maybeSingle();

    if (jobError) {
      throw new Error(`Failed to fetch job: ${jobError.message}`);
    }

    if (!jobRow) {
      throw new NotFoundError(`OCR job with ID '${jobId}' was not found.`);
    }

    const job = jobRow as OcrJob;

    // Strict ownership check
    if (job.user_id !== userId) {
      SecurityLogger.log('FORBIDDEN_DELETE_ACCESS', 'WARN', 'BLOCKED', {
        userId,
        targetJobId: jobId,
        jobOwnerId: job.user_id,
      });
      throw new ForbiddenError('You do not have permission to delete this OCR job.');
    }

    // 1. Delete image from Storage bucket
    if (job.storage_path) {
      const { error: storageError } = await supabaseAdmin.storage
        .from('ocr-images')
        .remove([job.storage_path]);

      if (storageError) {
        logger.warn(`[OcrService] Could not remove storage file ${job.storage_path}: ${storageError.message}`);
      }
    }

    // 2. Delete database row (cascades to ocr_job_results)
    const { error: deleteError } = await supabaseAdmin
      .from('ocr_jobs')
      .delete()
      .eq('id', jobId);

    if (deleteError) {
      throw new Error(`Failed to delete OCR job record: ${deleteError.message}`);
    }

    // 3. Clear Redis idempotency entry if present
    const redisKey = `ocr:idempotency:${userId}:${job.idempotency_key}`;
    await redis.del(redisKey);

    logger.info(`[OcrService] Job ${jobId} and storage file deleted by user ${userId}`);

    return {
      success: true,
      message: 'OCR job and associated image deleted successfully.',
    };
  }

  // ─── Internal Worker Signed URL ─────────────────────────────────────────────

  /**
   * Generates a short-lived internal signed URL for the worker to download the image.
   * Never exposed to clients.
   */
  static async createInternalSignedUrl(storagePath: string): Promise<string> {
    const { data, error } = await supabaseAdmin.storage
      .from('ocr-images')
      .createSignedUrl(storagePath, INTERNAL_SIGNED_URL_TTL);

    if (error || !data?.signedUrl) {
      throw new Error(`Could not generate internal signed URL: ${error?.message}`);
    }

    return data.signedUrl;
  }

  // ─── Response Builder Helper ────────────────────────────────────────────────

  private static buildResponseDto(job: OcrJob, result?: any): OcrJobStatusResponse {
    return {
      jobId: job.id,
      status: job.status,
      originalFilename: job.original_filename,
      fileSizeBytes: job.file_size_bytes,
      imageWidth: job.image_width,
      imageHeight: job.image_height,
      ocrType: job.ocr_type,
      processingType: job.processing_type,
      createdAt: job.created_at,
      updatedAt: job.updated_at,
      errorMessage: job.error_message,
      ...(result ? { result } : {}),
    };
  }
}
