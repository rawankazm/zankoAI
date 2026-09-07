// ==============================================================================
// ZankoAI AI Homework Solver Service
// ==============================================================================

import { supabaseAdmin } from '../../config/supabase.js';
import { logger } from '../../config/logger.js';
import { BadRequestError, ApiError } from '../../utils/apiError.js';
import {
  checkAbuseAndInjection,
  validateHomeworkImage,
  type SubmitHomeworkBody,
} from './validators/homework.validator.js';
import { GeminiHomeworkProvider } from './providers/homework/gemini_homework.provider.js';
import type {
  HomeworkSolutionData,
  HomeworkRecord,
} from '../../types/homework.types.js';

export class HomeworkService {
  private provider: GeminiHomeworkProvider;

  constructor(provider?: GeminiHomeworkProvider) {
    this.provider = provider || new GeminiHomeworkProvider();
  }

  /**
   * Solves a student or teacher homework question with structured educational output.
   * Enforces quota, rate limits, image validation, and abuse protection.
   */
  async solveHomework(
    userId: string,
    input: SubmitHomeworkBody,
    file?: Express.Multer.File,
    idempotencyKey?: string
  ): Promise<{ solution: HomeworkSolutionData; usage?: any }> {
    const startTime = Date.now();

    // ── 1. Input presence check ───────────────────────────────────────────────
    const hasText = Boolean(input.text && input.text.trim().length > 0);
    const hasFile = Boolean(file && file.buffer && file.buffer.length > 0);

    if (!hasText && !hasFile) {
      throw new BadRequestError('پێویستە دەق یان وێنەی پرسیار بنێریت بۆ ئەوەی شیکار بکرێت.');
    }

    // ── 2. Abuse & Prompt Injection check ─────────────────────────────────────
    checkAbuseAndInjection(input.text);

    // ── 3. Image validation (Magic bytes & dimensions) ────────────────────────
    let imageMimeType: string | undefined;
    if (hasFile && file) {
      const dimensions = validateHomeworkImage(file.buffer);
      imageMimeType = dimensions.format;
    }

    // ── 4. Idempotency check: Return existing record if already processed ─────
    if (idempotencyKey) {
      const { data: existingRecord, error: findError } = await supabaseAdmin
        .from('homework_requests')
        .select('*')
        .eq('user_id', userId)
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();

      if (!findError && existingRecord) {
        logger.info(`[HomeworkService] Returning cached solution for idempotency key: ${idempotencyKey}`);
        return {
          solution: this.mapRecordToSolution(existingRecord as HomeworkRecord),
        };
      }
    }

    // ── 5. Enforce and consume server-side usage quota ('homework') ───────────
    let usageInfo: any = null;
    try {
      const { data: quotaResult, error: quotaError } = await supabaseAdmin.rpc(
        'consume_feature_quota',
        {
          p_user_id: userId,
          p_feature: 'homework',
          p_increment: 1,
          p_idempotency_key: idempotencyKey || null,
        }
      );

      if (quotaError) {
        logger.error('[HomeworkService] Quota check RPC failed:', quotaError);
      } else if (quotaResult) {
        usageInfo = quotaResult;
        if (quotaResult.allowed === false) {
          throw new ApiError(
            429,
            `بەشی ڕۆژانەی شیکارکردنی پرسیار (Homework) تەواو بووە (${quotaResult.current_usage}/${quotaResult.limit}). تکایە هەژمارەکەت نوێبکەرەوە.`,
            'QUOTA_EXCEEDED'
          );
        }
      }
    } catch (err: any) {
      if (err instanceof ApiError) throw err;
      logger.warn('[HomeworkService] Non-blocking quota check error:', err);
    }

    // ── 6. Execute AI Problem Solving with Gemini ─────────────────────────────
    const aiResult = await this.provider.solve({
      text: input.text,
      imageBuffer: file?.buffer,
      imageMimeType,
      subject: input.subject,
      course: input.course,
      difficulty: input.difficulty,
      language: input.language,
    });

    const durationMs = Date.now() - startTime;

    // ── 7. Store metadata in public.homework_requests ─────────────────────────
    // Never store raw image base64; keep database lean and privacy-compliant.
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('homework_requests')
      .insert({
        user_id: userId,
        subject: input.subject,
        course: input.course || null,
        difficulty: input.difficulty,
        has_image: hasFile,
        image_mime_type: imageMimeType || null,
        text_prompt_length: input.text ? input.text.length : 0,
        language: input.language || 'ku',
        answer: aiResult.answer,
        explanation: aiResult.explanation,
        step_by_step: aiResult.stepByStepReasoning,
        mistakes_identified: aiResult.mistakesIdentified,
        hints: aiResult.hints,
        related_concepts: aiResult.relatedConcepts,
        duration_ms: durationMs,
        tokens_used: aiResult.tokensUsed || 0,
        idempotency_key: idempotencyKey || null,
      })
      .select('*')
      .single();

    if (insertError || !inserted) {
      logger.error('[HomeworkService] Failed to record homework metadata in Supabase:', insertError);
      // Fallback return solution directly if database insert fails
      const fallbackSolution: HomeworkSolutionData = {
        id: crypto.randomUUID(),
        subject: input.subject,
        course: input.course,
        difficulty: input.difficulty,
        answer: aiResult.answer,
        explanation: aiResult.explanation,
        stepByStepReasoning: aiResult.stepByStepReasoning,
        mistakesIdentified: aiResult.mistakesIdentified,
        hints: aiResult.hints,
        relatedConcepts: aiResult.relatedConcepts,
        language: input.language || 'ku',
        hasImage: hasFile,
        createdAt: new Date().toISOString(),
      };
      return { solution: fallbackSolution, usage: usageInfo };
    }

    return {
      solution: this.mapRecordToSolution(inserted as HomeworkRecord),
      usage: usageInfo,
    };
  }

  private mapRecordToSolution(record: HomeworkRecord): HomeworkSolutionData {
    return {
      id: record.id,
      subject: record.subject,
      course: record.course,
      difficulty: record.difficulty,
      answer: record.answer,
      explanation: record.explanation,
      stepByStepReasoning: record.step_by_step || [],
      mistakesIdentified: record.mistakes_identified || [],
      hints: record.hints || [],
      relatedConcepts: record.related_concepts || [],
      language: record.language,
      hasImage: record.has_image,
      createdAt: record.created_at,
    };
  }
}

export const homeworkService = new HomeworkService();
