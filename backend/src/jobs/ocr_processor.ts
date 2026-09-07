import axios from 'axios';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { validateExternalUrl } from '../utils/ssrfValidator.js';
import { validateMagicBytes } from '../middleware/uploadGuard.js';
import { getImageDimensions, validateImageDimensions } from '../utils/image_dimensions.js';
import { OcrOrchestrator } from '../modules/ai/providers/ocr/ocr_orchestrator.service.js';
import {
  OcrAiJobData,
  OcrProcessingType,
  OcrQuestion,
  OcrQuiz,
  OcrFlashcard,
} from '../types/ocr.types.js';

/** Maximum download size for OCR image (10 MB) */
const MAX_DOWNLOAD_SIZE = 10 * 1024 * 1024;

/** Minimum extracted text length to proceed with AI processing */
const MIN_TEXT_LENGTH = 5;

/** Maximum text characters passed to downstream AI generation */
const MAX_TEXT_FOR_AI = 10000;

export async function processOcrAiJob(data: OcrAiJobData): Promise<void> {
  const { jobId, userId, storagePath, ocrType, processingType, originalFilename } = data;

  logger.info(`[OcrProcessor] Starting job ${jobId} (ocrType=${ocrType}, file=${originalFilename})`);

  // 1. Mark job as processing
  await updateJobStatus(jobId, 'processing');

  let signedUrl: string;

  try {
    // 2. Generate short-lived internal signed URL (15 min)
    const { OcrService } = await import('../modules/ai/ocr.service.js');
    signedUrl = await OcrService.createInternalSignedUrl(storagePath);
  } catch (err: any) {
    logger.error(`[OcrProcessor] Failed to create signed URL for job ${jobId}: ${err.message}`);
    await failJob(jobId, `Storage access failed: ${err.message}`);
    throw err;
  }

  let buffer: Buffer;

  try {
    // 3. SSRF protection + download
    validateExternalUrl(signedUrl);

    const response = await axios.get<ArrayBuffer>(signedUrl, {
      responseType: 'arraybuffer',
      timeout: 20_000,
      maxContentLength: MAX_DOWNLOAD_SIZE,
    });
    buffer = Buffer.from(response.data);
  } catch (err: any) {
    logger.error(`[OcrProcessor] Download failed for job ${jobId}: ${err.message}`);
    await failJob(jobId, `File download failed: ${err.message}`);
    throw err;
  }

  try {
    // 4. Re-validate magic bytes & dimensions
    const magicCheck = validateMagicBytes(buffer);
    if (!magicCheck.isValid || !magicCheck.detectedType?.startsWith('image/')) {
      throw new Error('Downloaded file does not match a valid image format (magic bytes check failed).');
    }

    const mimeType = magicCheck.detectedType;
    const dimensions = getImageDimensions(buffer);
    validateImageDimensions(dimensions);

    // Update dimensions in DB if they were 0
    await supabaseAdmin
      .from('ocr_jobs')
      .update({
        image_width: dimensions.width,
        image_height: dimensions.height,
      })
      .eq('id', jobId);

    // 5. Perform OCR extraction via Provider Orchestrator
    const orchestrator = OcrOrchestrator.getInstance();
    const ocrResult = await orchestrator.extractText(buffer, mimeType, {
      mode: ocrType,
      languageHint: 'Kurdish, Arabic, English',
    });

    const rawText = ocrResult.rawText.trim();
    if (rawText.length < MIN_TEXT_LENGTH) {
      throw new Error(
        `OCR could not detect any readable text in the image (found ${rawText.length} characters). Please ensure the image is clear and well-lit.`
      );
    }

    logger.info(`[OcrProcessor] Job ${jobId}: extracted ${rawText.length} chars (${ocrResult.detectedType}, provider=${ocrResult.provider})`);

    // 6. Generate AI Study Aids if requested
    const truncatedText = rawText.length > MAX_TEXT_FOR_AI ? rawText.substring(0, MAX_TEXT_FOR_AI) : rawText;
    const aiOutputs = await generateAiOutputs(userId, originalFilename, truncatedText, processingType);

    // 7. Store results in ocr_job_results
    const { error: insertError } = await supabaseAdmin.from('ocr_job_results').insert({
      job_id: jobId,
      user_id: userId,
      extracted_text: rawText,
      detected_text_type: ocrResult.detectedType,
      confidence_score: ocrResult.confidence,
      summary: aiOutputs.summary,
      questions: aiOutputs.questions ?? [],
      quiz: aiOutputs.quiz ?? {},
      flashcards: aiOutputs.flashcards ?? [],
      ocr_provider: ocrResult.provider,
      extracted_text_length: rawText.length,
    });

    if (insertError) {
      throw new Error(`Failed to persist OCR results: ${insertError.message}`);
    }

    // 8. Mark job as completed
    await updateJobStatus(jobId, 'completed');
    logger.info(`[OcrProcessor] Job ${jobId} successfully completed.`);
  } catch (err: any) {
    logger.error(`[OcrProcessor] Job ${jobId} failed: ${err.message}`);
    await failJob(jobId, err.message);
    throw err;
  }
}

// ─── AI Study Aid Generation ──────────────────────────────────────────────────

async function generateAiOutputs(
  userId: string,
  filename: string,
  text: string,
  processingType: OcrProcessingType
): Promise<{
  summary: string | null;
  questions: OcrQuestion[] | null;
  quiz: OcrQuiz | null;
  flashcards: OcrFlashcard[] | null;
}> {
  const results: {
    summary: string | null;
    questions: OcrQuestion[] | null;
    quiz: OcrQuiz | null;
    flashcards: OcrFlashcard[] | null;
  } = {
    summary: null,
    questions: null,
    quiz: null,
    flashcards: null,
  };

  if (processingType === 'extract_only') {
    return results;
  }

  const { aiGateway } = await import('../modules/ai/ai.service.js');
  const doAll = processingType === 'all';

  // ── Summarize ─────────────────────────────────────────────────────────────
  if (doAll || processingType === 'summarize') {
    try {
      const prompt =
        `You are an expert academic summarizer. Read the following text extracted from an image (${filename}) and produce a comprehensive, well-structured summary in the same language as the text (Kurdish, Arabic, or English).\n\n` +
        `Text:\n${text}\n\n` +
        `Write a clear, structured summary highlighting key concepts, formulas, and conclusions.`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      results.summary = result.text;
    } catch (err: any) {
      logger.warn(`[OcrProcessor] Summary generation failed: ${err.message}`);
    }
  }

  // ── Questions ─────────────────────────────────────────────────────────────
  if (doAll || processingType === 'questions') {
    try {
      const prompt =
        `Based on the following extracted document text, generate 5 to 10 academic study questions with comprehensive answers. Respond ONLY with valid JSON in this exact format:\n` +
        `[{"id":"1","question":"...","answer":"..."}]\n\n` +
        `Text:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '[');
      results.questions = JSON.parse(clean) as OcrQuestion[];
    } catch (err: any) {
      logger.warn(`[OcrProcessor] Question generation failed: ${err.message}`);
    }
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────
  if (doAll || processingType === 'quiz') {
    try {
      const prompt =
        `Based on the following extracted text, create an academic quiz with multiple-choice questions. Respond ONLY with valid JSON in this exact format:\n` +
        `{"title":"Quiz: ${filename}","questions":[{"question":"...","options":["A","B","C","D"],"correctAnswer":0,"explanation":"..."}]}\n\n` +
        `Text:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '{');
      results.quiz = JSON.parse(clean) as OcrQuiz;
    } catch (err: any) {
      logger.warn(`[OcrProcessor] Quiz generation failed: ${err.message}`);
    }
  }

  // ── Flashcards ────────────────────────────────────────────────────────────
  if (doAll || processingType === 'flashcards') {
    try {
      const prompt =
        `Based on the following extracted text, create 10 study flashcards covering key definitions, terms, or facts. Respond ONLY with valid JSON in this exact format:\n` +
        `[{"id":"1","front":"Term / Question","back":"Definition / Answer"}]\n\n` +
        `Text:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '[');
      results.flashcards = JSON.parse(clean) as OcrFlashcard[];
    } catch (err: any) {
      logger.warn(`[OcrProcessor] Flashcard generation failed: ${err.message}`);
    }
  }

  return results;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function extractJson(text: string, startChar: '{' | '['): string {
  const startIdx = text.indexOf(startChar);
  if (startIdx === -1) throw new Error(`No JSON opening bracket '${startChar}' found in response`);

  const endChar = startChar === '{' ? '}' : ']';
  const endIdx = text.lastIndexOf(endChar);
  if (endIdx === -1) throw new Error(`No JSON closing bracket '${endChar}' found in response`);

  return text.substring(startIdx, endIdx + 1);
}

async function updateJobStatus(jobId: string, status: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from('ocr_jobs')
    .update({ status })
    .eq('id', jobId);

  if (error) {
    logger.error(`[OcrProcessor] Failed to update status to '${status}' for job ${jobId}: ${error.message}`);
  }
}

async function failJob(jobId: string, errorMessage: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from('ocr_jobs')
    .update({
      status: 'failed',
      error_message: errorMessage,
    })
    .eq('id', jobId);

  if (error) {
    logger.error(`[OcrProcessor] Failed to mark job ${jobId} as failed: ${error.message}`);
  }
}
