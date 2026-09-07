import crypto from 'crypto';
import path from 'path';
import { supabaseAdmin } from '../../config/supabase.js';
import { logger } from '../../config/logger.js';
import { redis } from '../../config/redis.js';
import { SecurityLogger } from '../../utils/securityLogger.js';
import { validateAudioMagicBytes } from '../../utils/audio_format_validator.js';
import { audioTranscriptionQueue } from '../../jobs/queues.js';
import { UsageService } from '../../services/usage.service.js';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
  QuotaExceededError,
} from '../../utils/apiError.js';
import {
  LectureAudioJob,
  LectureAudioResponseDto,
  LectureAudioJobData,
} from '../../types/audio.types.js';
import { SubmitAudioJobBody } from './validators/audio.validator.js';

/** Signed URL TTL for internal worker downloads (seconds) */
const INTERNAL_SIGNED_URL_TTL = 900; // 15 minutes

/** Idempotency key Redis TTL (seconds) */
const IDEMPOTENCY_TTL = 86400; // 24 hours

export class AudioService {
  // ─── Submit Lecture Audio Job ───────────────────────────────────────────────

  /**
   * Validates teacher permissions, course assignment, quota, and audio integrity,
   * then enqueues the recording for transcription and AI generation.
   */
  static async submitJob(
    userId: string,
    file: Express.Multer.File,
    body: SubmitAudioJobBody,
    idempotencyKey?: string
  ): Promise<LectureAudioResponseDto> {
    const { courseId, title, lectureId, language, durationSeconds } = body;

    // 1. Verify user has 'teacher' or 'admin' role
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('id, role')
      .eq('id', userId)
      .maybeSingle();

    if (!profile || (profile.role !== 'teacher' && profile.role !== 'admin')) {
      SecurityLogger.log('UNAUTHORIZED_TEACHER_ACTION', 'WARN', 'BLOCKED', {
        userId,
        attemptedRole: profile?.role,
        action: 'create_lecture_audio',
      });
      throw new ForbiddenError('Only authorized teachers can create and upload lecture recordings.');
    }

    // 2. Verify teacher is assigned to this course
    const { data: isAuthorized, error: authErr } = await supabaseAdmin.rpc(
      'is_authorized_course_teacher',
      {
        p_course_id: courseId,
        p_user_id: userId,
      }
    );

    if (authErr || isAuthorized !== true) {
      SecurityLogger.log('FORBIDDEN_COURSE_ACCESS', 'WARN', 'BLOCKED', {
        userId,
        courseId,
        reason: 'Teacher not assigned to course',
      });
      throw new ForbiddenError('You are not authorized to publish lecture audio for this course.');
    }

    // 3. Derive idempotency key
    const idemKey =
      idempotencyKey?.trim() ||
      crypto
        .createHash('sha256')
        .update(`${userId}:${courseId}:${file.originalname}:${file.size}`)
        .digest('hex');

    // 4. Check idempotency cache in Redis
    const redisKey = `audio:idempotency:${userId}:${idemKey}`;
    const existingJobId = await redis.get(redisKey);
    if (existingJobId) {
      logger.info(`[AudioService] Idempotent replay for audio job ${existingJobId} (teacher ${userId})`);
      return this.getJobStatus(existingJobId, userId);
    }

    // 5. Server-authoritative quota consumption
    const quotaResult = await UsageService.consumeQuota(userId, 'audio', 1, idemKey);
    if (!quotaResult.allowed) {
      throw new QuotaExceededError(
        `Monthly audio lecture recording limit reached (${quotaResult.current_usage}/${quotaResult.limit}). Please upgrade your plan.`,
        quotaResult
      );
    }

    // 6. Audio binary signature check
    if (!file.buffer || !Buffer.isBuffer(file.buffer)) {
      throw new BadRequestError('File buffer is missing. Upload must include audio content.');
    }

    const audioCheck = validateAudioMagicBytes(file.buffer);
    if (!audioCheck.isValid) {
      SecurityLogger.log('MALICIOUS_UPLOAD_BLOCKED', 'CRITICAL', 'BLOCKED', {
        userId,
        filename: file.originalname,
        reason: 'Failed audio magic bytes validation',
      });
      throw new BadRequestError(
        'Security check failed: File content does not match a valid audio format (MP3, WAV, M4A, AAC, OGG, WebM).'
      );
    }

    // 7. Upload to Supabase Storage (audio bucket)
    const uniqueId = crypto.randomUUID();
    const ext = path.extname(file.originalname).toLowerCase() || (audioCheck.detectedFormat ? `.${audioCheck.detectedFormat}` : '.m4a');
    const storagePath = `${courseId}/${uniqueId}${ext}`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from('audio')
      .upload(storagePath, file.buffer, {
        contentType: audioCheck.detectedMime || file.mimetype || 'audio/mp4',
        upsert: false,
      });

    if (uploadError) {
      logger.error(`[AudioService] Storage upload failed: ${uploadError.message}`);
      throw new Error(`Audio storage upload failed: ${uploadError.message}`);
    }

    // 8. Insert record into lecture_audio_jobs
    const { data: jobRow, error: dbError } = await supabaseAdmin
      .from('lecture_audio_jobs')
      .insert({
        teacher_id: userId,
        course_id: courseId,
        lecture_id: lectureId || null,
        title,
        storage_path: storagePath,
        file_size_bytes: file.size,
        duration_seconds: durationSeconds || 0,
        audio_format: audioCheck.detectedMime || file.mimetype || 'audio/mp4',
        idempotency_key: idemKey,
        status: 'queued',
        is_published: true,
      })
      .select('*')
      .single();

    if (dbError || !jobRow) {
      await supabaseAdmin.storage.from('audio').remove([storagePath]);
      logger.error(`[AudioService] Failed to insert lecture_audio_jobs: ${dbError?.message}`);
      throw new Error(`Database record creation failed: ${dbError?.message}`);
    }

    const job = jobRow as LectureAudioJob;

    // 9. Cache in Redis
    await redis.set(redisKey, job.id, 'EX', IDEMPOTENCY_TTL);

    // 10. Enqueue BullMQ job
    const queueData: LectureAudioJobData = {
      jobId: job.id,
      teacherId: userId,
      courseId,
      lectureId,
      title,
      storagePath,
      audioFormat: job.audioFormat,
      fileSizeBytes: file.size,
      languageHint: language,
    };

    const bullmqJob = await audioTranscriptionQueue.add('process-audio', queueData, {
      jobId: job.id,
      priority: 1,
    });

    await supabaseAdmin
      .from('lecture_audio_jobs')
      .update({ bullmq_job_id: bullmqJob.id })
      .eq('id', job.id);

    logger.info(`[AudioService] Audio lecture job ${job.id} enqueued successfully.`);

    return this.buildResponseDto(job);
  }

  // ─── Get Job Status & Results ───────────────────────────────────────────────

  /**
   * Retrieves status and results. Enforces strict course membership protection:
   * Only the teacher, enrolled students, or admins can access.
   */
  static async getJobStatus(jobId: string, userId: string): Promise<LectureAudioResponseDto> {
    const { data: jobRow, error: jobError } = await supabaseAdmin
      .from('lecture_audio_jobs')
      .select('*')
      .eq('id', jobId)
      .maybeSingle();

    if (jobError) {
      throw new Error(`Failed to fetch lecture audio job: ${jobError.message}`);
    }

    if (!jobRow) {
      throw new NotFoundError(`Lecture audio job with ID '${jobId}' was not found.`);
    }

    const job = jobRow as LectureAudioJob;

    // Verify course membership access
    const { data: canAccess, error: accessErr } = await supabaseAdmin.rpc(
      'can_access_lecture_audio',
      {
        p_job_id: jobId,
        p_user_id: userId,
      }
    );

    if (accessErr || canAccess !== true) {
      SecurityLogger.log('FORBIDDEN_COURSE_CONTENT_ACCESS', 'WARN', 'BLOCKED', {
        userId,
        targetJobId: jobId,
        courseId: job.courseId,
      });
      throw new ForbiddenError(
        'You are not authorized to view this lecture recording. Only enrolled students and instructors have access.'
      );
    }

    let result: any = null;
    if (job.status === 'completed') {
      const { data: resRow } = await supabaseAdmin
        .from('lecture_audio_results')
        .select('*')
        .eq('job_id', jobId)
        .maybeSingle();

      if (resRow) {
        result = {
          transcript: resRow.transcript,
          summary: resRow.summary,
          keyTakeaways: resRow.key_takeaways || [],
          flashcards: resRow.flashcards || [],
          quiz: resRow.quiz || {},
          languageDetected: resRow.language_detected,
        };
      }
    }

    return this.buildResponseDto(job, result);
  }

  // ─── Delete Job ─────────────────────────────────────────────────────────────

  /**
   * Only the teacher who recorded the lecture or an admin can delete it.
   */
  static async deleteJob(
    jobId: string,
    userId: string
  ): Promise<{ success: boolean; message: string }> {
    const { data: jobRow, error: jobError } = await supabaseAdmin
      .from('lecture_audio_jobs')
      .select('*')
      .eq('id', jobId)
      .maybeSingle();

    if (jobError || !jobRow) {
      throw new NotFoundError(`Lecture audio job '${jobId}' not found.`);
    }

    const job = jobRow as LectureAudioJob;

    // Check teacher ownership
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .maybeSingle();

    const isAdmin = profile?.role === 'admin';
    if (job.teacherId !== userId && !isAdmin) {
      throw new ForbiddenError('Only the recording teacher or an admin can delete this lecture.');
    }

    // Remove storage file
    if (job.storagePath) {
      await supabaseAdmin.storage.from('audio').remove([job.storagePath]);
    }

    // Delete database row (cascades to results)
    await supabaseAdmin.from('lecture_audio_jobs').delete().eq('id', jobId);

    // Remove idempotency cache
    await redis.del(`audio:idempotency:${job.teacherId}:${job.idempotencyKey}`);

    logger.info(`[AudioService] Lecture audio job ${jobId} deleted by ${userId}`);

    return {
      success: true,
      message: 'Lecture recording and AI results deleted successfully.',
    };
  }

  // ─── Internal Worker Signed URL ─────────────────────────────────────────────

  static async createInternalSignedUrl(storagePath: string): Promise<string> {
    const { data, error } = await supabaseAdmin.storage
      .from('audio')
      .createSignedUrl(storagePath, INTERNAL_SIGNED_URL_TTL);

    if (error || !data?.signedUrl) {
      throw new Error(`Could not generate internal signed URL for audio: ${error?.message}`);
    }

    return data.signedUrl;
  }

  // ─── Helper ─────────────────────────────────────────────────────────────────

  private static buildResponseDto(job: LectureAudioJob, result?: any): LectureAudioResponseDto {
    return {
      jobId: job.id,
      status: job.status,
      courseId: job.courseId,
      lectureId: job.lectureId,
      title: job.title,
      fileSizeBytes: job.fileSizeBytes,
      durationSeconds: job.durationSeconds,
      audioFormat: job.audioFormat,
      isPublished: job.isPublished,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      errorMessage: job.errorMessage,
      ...(result ? { result } : {}),
    };
  }
}
