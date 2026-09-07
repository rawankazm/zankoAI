import crypto from 'crypto';
import axios from 'axios';
import pdfParse from 'pdf-parse';
import { supabaseAdmin } from '../../config/supabase.js';
import { logger } from '../../config/logger.js';
import { redis } from '../../config/redis.js';
import { SecurityLogger } from '../../utils/securityLogger.js';
import { validateMagicBytes } from '../../middleware/uploadGuard.js';
import { validateExternalUrl } from '../../utils/ssrfValidator.js';
import { pdfAiQueue } from '../../jobs/queues.js';
import { UsageService } from '../../services/usage.service.js';
import {
  BadRequestError,
  NotFoundError,
  ForbiddenError,
  QuotaExceededError,
} from '../../utils/apiError.js';
import {
  PdfJob,
  PdfJobStatusResponse,
  PdfProcessingType,
  PdfAiJobData,
} from '../../types/pdf.types.js';

/** Max pages to process; hard reject above this */
const MAX_PAGE_COUNT = 500;

/** Min extracted text length to consider a PDF readable */
const MIN_TEXT_LENGTH = 50;

/** Signed URL TTL for internal worker downloads (seconds) */
const INTERNAL_SIGNED_URL_TTL = 900; // 15 minutes

/** Idempotency key Redis TTL (seconds) */
const IDEMPOTENCY_TTL = 86400; // 24 hours

export class PdfService {
  // ─── Submit Job ────────────────────────────────────────────────────────────

  /**
   * Validate, upload, and enqueue a PDF for AI processing.
   * Idempotency: duplicate requests with same key return the existing job without re-charging.
   */
  static async submitJob(
    userId: string,
    file: Express.Multer.File,
    processingType: PdfProcessingType,
    idempotencyKey?: string
  ): Promise<PdfJobStatusResponse> {
    // 1. Derive idempotency key (caller-supplied or hash of content)
    const idemKey = idempotencyKey?.trim() ||
      crypto
        .createHash('sha256')
        .update(`${userId}:${file.originalname}:${file.size}`)
        .digest('hex');

    // 2. Idempotency check in Redis
    const redisKey = `pdf:idempotency:${userId}:${idemKey}`;
    const existingJobId = await redis.get(redisKey);
    if (existingJobId) {
      logger.info(`[PdfService] Idempotent replay for job ${existingJobId} (user ${userId})`);
      return this.getJobStatus(existingJobId, userId, true);
    }

    // 3. Server-authoritative quota enforcement (before any storage write)
    const quotaResult = await UsageService.consumeQuota(userId, 'pdf', 1, idemKey);
    if (!quotaResult.allowed) {
      throw new QuotaExceededError(
        `Monthly PDF processing limit reached (${quotaResult.current_usage}/${quotaResult.limit}). Please upgrade your plan.`,
        quotaResult
      );
    }

    // 4. Re-validate magic bytes on the in-memory buffer
    if (!file.buffer || !Buffer.isBuffer(file.buffer)) {
      throw new BadRequestError('File buffer is missing. Upload must include file content.');
    }
    const magicCheck = validateMagicBytes(file.buffer);
    if (!magicCheck.isValid || magicCheck.detectedType !== 'application/pdf') {
      SecurityLogger.log('MALICIOUS_UPLOAD_BLOCKED', 'CRITICAL', 'BLOCKED', {
        userId,
        reason: 'Magic bytes do not match PDF structure',
        filename: file.originalname,
      });
      throw new BadRequestError(
        'Security check failed: File content does not match a genuine PDF document.'
      );
    }

    // 5. Validate page count (quick parse — lightweight)
    let pageCount = 0;
    try {
      const parsed = await pdfParse(file.buffer, { max: 1 }); // parse only metadata
      pageCount = parsed.numpages || 0;
    } catch {
      // Non-critical: page count check failed; proceed with pageCount=0
      logger.warn(`[PdfService] Could not parse page count for ${file.originalname}`);
    }

    if (pageCount > MAX_PAGE_COUNT) {
      throw new BadRequestError(
        `PDF exceeds maximum page limit (${pageCount} pages). Maximum allowed: ${MAX_PAGE_COUNT} pages.`
      );
    }

    // 6. Upload buffer to Supabase Storage (pdfs bucket)
    const uniqueId = crypto.randomUUID();
    const storagePath = `${userId}/${uniqueId}.pdf`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from('pdfs')
      .upload(storagePath, file.buffer, {
        contentType: 'application/pdf',
        upsert: false,
      });

    if (uploadError) {
      logger.error(`[PdfService] Storage upload failed for user ${userId}: ${uploadError.message}`);
      throw new Error(`Storage upload failed: ${uploadError.message}`);
    }

    logger.info(`[PdfService] Uploaded PDF to pdfs/${storagePath} (${file.size} bytes)`);

    // 7. Insert pdf_jobs row
    const { data: jobRow, error: insertError } = await supabaseAdmin
      .from('pdf_jobs')
      .insert({
        user_id: userId,
        idempotency_key: idemKey,
        original_filename: file.originalname,
        storage_path: storagePath,
        file_size_bytes: file.size,
        page_count: pageCount,
        processing_type: processingType,
        status: 'queued',
      })
      .select()
      .single();

    if (insertError || !jobRow) {
      // Rollback: delete uploaded file to avoid orphan
      await supabaseAdmin.storage.from('pdfs').remove([storagePath]);
      logger.error(`[PdfService] Failed to insert pdf_jobs row: ${insertError?.message}`);
      throw new Error(`Failed to create processing job: ${insertError?.message}`);
    }

    const job = jobRow as PdfJob;

    // 8. Enqueue BullMQ job
    const jobData: PdfAiJobData = {
      jobId: job.id,
      userId,
      storagePath,
      processingType,
      originalFilename: file.originalname,
    };

    const bullJob = await pdfAiQueue.add('process-pdf-ai', jobData, {
      jobId: `pdf-ai:${job.id}`,  // deterministic BullMQ job ID for deduplication
    });

    // 9. Persist BullMQ job ID back to DB
    await supabaseAdmin
      .from('pdf_jobs')
      .update({ bullmq_job_id: bullJob.id })
      .eq('id', job.id);

    // 10. Cache idempotency key in Redis
    await redis.set(redisKey, job.id, 'EX', IDEMPOTENCY_TTL);

    logger.info(`[PdfService] Job ${job.id} queued (BullMQ: ${bullJob.id}) for user ${userId}`);

    return {
      jobId: job.id,
      status: 'queued',
      originalFilename: job.original_filename,
      fileSizeBytes: job.file_size_bytes,
      pageCount: job.page_count,
      processingType: job.processing_type,
      errorMessage: null,
      createdAt: job.created_at,
      updatedAt: job.updated_at,
      usage: {
        remaining: quotaResult.remaining,
        limit: quotaResult.limit,
        resetAt: quotaResult.reset_at,
      },
    };
  }

  // ─── Get Job Status ────────────────────────────────────────────────────────

  /**
   * Returns the current status and result (if completed) for a job.
   * Enforces strict user ownership — never exposes raw storage paths.
   */
  static async getJobStatus(
    jobId: string,
    userId: string,
    isIdempotentReplay = false
  ): Promise<PdfJobStatusResponse> {
    const { data: jobRow, error } = await supabaseAdmin
      .from('pdf_jobs')
      .select('*')
      .eq('id', jobId)
      .maybeSingle();

    if (error || !jobRow) {
      throw new NotFoundError(`PDF processing job not found: ${jobId}`);
    }

    const job = jobRow as PdfJob;

    // Ownership enforcement (belt-and-suspenders beyond RLS)
    if (job.user_id !== userId) {
      SecurityLogger.log('IDOR_ATTEMPT', 'CRITICAL', 'BLOCKED', {
        userId,
        targetJobId: jobId,
        targetOwner: job.user_id,
      });
      throw new ForbiddenError('Access denied: You can only access your own PDF processing jobs.');
    }

    const response: PdfJobStatusResponse = {
      jobId: job.id,
      status: job.status,
      originalFilename: job.original_filename,
      fileSizeBytes: job.file_size_bytes,
      pageCount: job.page_count,
      processingType: job.processing_type,
      errorMessage: job.error_message,
      createdAt: job.created_at,
      updatedAt: job.updated_at,
    };

    // Attach results if completed
    if (job.status === 'completed') {
      const { data: resultRow } = await supabaseAdmin
        .from('pdf_job_results')
        .select('summary, questions, quiz, flashcards, extracted_text_length')
        .eq('job_id', jobId)
        .maybeSingle();

      if (resultRow) {
        response.result = {
          summary: resultRow.summary ?? null,
          questions: resultRow.questions ?? null,
          quiz: resultRow.quiz ?? null,
          flashcards: resultRow.flashcards ?? null,
          extractedTextLength: resultRow.extracted_text_length,
        };
      }
    }

    return response;
  }

  // ─── Ask Question about PDF ────────────────────────────────────────────────

  /**
   * Answers a user question using the extracted text as context.
   * Requires the job to be completed. Uses ai_chat quota.
   */
  static async askQuestion(
    jobId: string,
    userId: string,
    question: string
  ): Promise<string> {
    // 1. Fetch and verify job
    const { data: jobRow, error } = await supabaseAdmin
      .from('pdf_jobs')
      .select('id, user_id, status, original_filename')
      .eq('id', jobId)
      .maybeSingle();

    if (error || !jobRow) {
      throw new NotFoundError(`PDF job not found: ${jobId}`);
    }

    if (jobRow.user_id !== userId) {
      throw new ForbiddenError('Access denied: Cannot query another user\'s PDF.');
    }

    if (jobRow.status !== 'completed') {
      throw new BadRequestError(
        `Cannot ask questions about a PDF that is not yet completed (current status: ${jobRow.status}).`
      );
    }

    // 2. Fetch result to get summary + questions as context
    const { data: resultRow } = await supabaseAdmin
      .from('pdf_job_results')
      .select('summary, questions, flashcards')
      .eq('job_id', jobId)
      .maybeSingle();

    if (!resultRow) {
      throw new NotFoundError('PDF job result not found. The job may still be processing.');
    }

    // 3. Build context from stored AI outputs (we never re-download the PDF)
    const contextParts: string[] = [
      `Document: "${jobRow.original_filename}"`,
    ];

    if (resultRow.summary) {
      contextParts.push(`Summary:\n${resultRow.summary}`);
    }

    if (Array.isArray(resultRow.questions) && resultRow.questions.length > 0) {
      const qLines = resultRow.questions
        .slice(0, 10)
        .map((q: any, i: number) => `Q${i + 1}: ${q.question}\nA: ${q.answer}`)
        .join('\n');
      contextParts.push(`Key Questions & Answers:\n${qLines}`);
    }

    if (Array.isArray(resultRow.flashcards) && resultRow.flashcards.length > 0) {
      const fcLines = resultRow.flashcards
        .slice(0, 10)
        .map((f: any) => `• ${f.front}: ${f.back}`)
        .join('\n');
      contextParts.push(`Key Concepts:\n${fcLines}`);
    }

    const context = contextParts.join('\n\n');

    // 4. Build prompt with injected document context
    const systemPrompt = `You are ZankoAI, an academic assistant. The user is asking a question about a specific PDF document.
Use ONLY the information provided below to answer. If the answer is not in the context, say so clearly.

--- DOCUMENT CONTEXT ---
${context}
--- END CONTEXT ---`;

    // 5. Call AI via orchestrator (lazy import to avoid circular dependency)
    const { aiGateway } = await import('./ai.service.js');
    const result = await aiGateway.chatWithTeacher(userId, question, [
      { role: 'system', content: systemPrompt },
    ]);

    return result.text;
  }

  // ─── Internal: Generate Signed URL ────────────────────────────────────────

  /**
   * Creates a short-lived signed download URL for internal worker use only.
   * This URL is NEVER returned to clients.
   */
  static async createInternalSignedUrl(storagePath: string): Promise<string> {
    const { data, error } = await supabaseAdmin.storage
      .from('pdfs')
      .createSignedUrl(storagePath, INTERNAL_SIGNED_URL_TTL);

    if (error || !data) {
      throw new Error(`Failed to create internal signed URL: ${error?.message}`);
    }

    // SSRF protection: validate that the URL resolves to Supabase (not internal network)
    validateExternalUrl(data.signedUrl);

    return data.signedUrl;
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  /**
   * Delete a storage file for a given PDF job.
   * Called by cleanup job for failed/orphaned entries.
   */
  static async deleteJobStorage(storagePath: string): Promise<void> {
    const { error } = await supabaseAdmin.storage.from('pdfs').remove([storagePath]);
    if (error) {
      logger.warn(`[PdfService] Failed to delete storage file pdfs/${storagePath}: ${error.message}`);
    }
  }
}
