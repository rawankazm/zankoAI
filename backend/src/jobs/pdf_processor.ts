import axios from 'axios';
import pdfParse from 'pdf-parse';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { validateExternalUrl } from '../utils/ssrfValidator.js';
import { validateMagicBytes } from '../middleware/uploadGuard.js';
import {
  PdfAiJobData,
  PdfProcessingType,
  PdfQuestion,
  PdfQuiz,
  PdfFlashcard,
} from '../types/pdf.types.js';

/** Maximum file size the worker will download (30 MB) */
const MAX_DOWNLOAD_SIZE = 30 * 1024 * 1024;

/** Minimum extracted text length to proceed with AI processing */
const MIN_TEXT_LENGTH = 50;

/** Maximum characters of text sent to AI (to keep prompts within token limits) */
const MAX_TEXT_FOR_AI = 12000;

/**
 * Full async PDF AI processing job.
 * Called by the BullMQ worker. Updates pdf_jobs status throughout.
 */
export async function processPdfAiJob(data: PdfAiJobData): Promise<void> {
  const { jobId, userId, storagePath, processingType, originalFilename } = data;

  logger.info(`[PdfProcessor] Starting job ${jobId} (type=${processingType}, file=${originalFilename})`);

  // ── Mark job as processing ────────────────────────────────────────────────
  await updateJobStatus(jobId, 'processing');

  let signedUrl: string;

  try {
    // ── 1. Generate internal signed URL (never exposed to clients) ─────────
    const { PdfService } = await import('../modules/ai/pdf.service.js');
    signedUrl = await PdfService.createInternalSignedUrl(storagePath);
  } catch (err: any) {
    logger.error(`[PdfProcessor] Failed to create signed URL for job ${jobId}: ${err.message}`);
    await failJob(jobId, `Storage access failed: ${err.message}`);
    throw err;
  }

  let buffer: Buffer;

  try {
    // ── 2. SSRF protection + download ─────────────────────────────────────
    validateExternalUrl(signedUrl);

    const response = await axios.get<ArrayBuffer>(signedUrl, {
      responseType: 'arraybuffer',
      timeout: 20_000,
      maxContentLength: MAX_DOWNLOAD_SIZE,
    });
    buffer = Buffer.from(response.data);
  } catch (err: any) {
    logger.error(`[PdfProcessor] Download failed for job ${jobId}: ${err.message}`);
    await failJob(jobId, `File download failed: ${err.message}`);
    throw err;
  }

  try {
    // ── 3. Re-validate magic bytes ────────────────────────────────────────
    const magicCheck = validateMagicBytes(buffer);
    if (!magicCheck.isValid || magicCheck.detectedType !== 'application/pdf') {
      throw new Error('Downloaded content does not match genuine PDF structure (magic bytes check failed).');
    }

    // ── 4. Extract text with pdf-parse ────────────────────────────────────
    let extractedText = '';
    let pageCount = 0;

    try {
      const parsed = await pdfParse(buffer);
      extractedText = (parsed.text || '').trim();
      pageCount = parsed.numpages || 0;
    } catch (parseErr: any) {
      throw new Error(`PDF parsing failed: ${parseErr.message}`);
    }

    // ── 5. Validate extracted text ────────────────────────────────────────
    if (extractedText.length < MIN_TEXT_LENGTH) {
      throw new Error(
        `PDF appears to be empty or image-only (extracted ${extractedText.length} chars). ` +
        `OCR is required for scanned documents. Minimum readable text: ${MIN_TEXT_LENGTH} chars.`
      );
    }

    logger.info(
      `[PdfProcessor] Job ${jobId}: extracted ${extractedText.length} chars from ${pageCount} pages`
    );

    // Update page count if it changed
    await supabaseAdmin
      .from('pdf_jobs')
      .update({ page_count: pageCount })
      .eq('id', jobId);

    // ── 6. AI Processing ──────────────────────────────────────────────────
    const textForAI = extractedText.slice(0, MAX_TEXT_FOR_AI);

    const results = await runAiProcessing(userId, textForAI, originalFilename, processingType);

    // ── 7. Store results in pdf_job_results ───────────────────────────────
    const { error: insertError } = await supabaseAdmin
      .from('pdf_job_results')
      .insert({
        job_id: jobId,
        user_id: userId,
        summary: results.summary,
        questions: results.questions ?? [],
        quiz: results.quiz ?? {},
        flashcards: results.flashcards ?? [],
        extracted_text_length: extractedText.length,
      });

    if (insertError) {
      throw new Error(`Failed to store results: ${insertError.message}`);
    }

    // ── 8. Mark job completed ──────────────────────────────────────────────
    await supabaseAdmin
      .from('pdf_jobs')
      .update({
        status: 'completed',
        error_message: null,
      })
      .eq('id', jobId);

    logger.info(`[PdfProcessor] Job ${jobId} completed successfully`);
  } catch (err: any) {
    logger.error(`[PdfProcessor] Job ${jobId} failed: ${err.message}`);
    await failJob(jobId, err.message || 'Unknown processing error');
    throw err; // rethrow so BullMQ handles retry logic
  }
}

// ─── AI Processing Orchestration ─────────────────────────────────────────────

async function runAiProcessing(
  userId: string,
  text: string,
  filename: string,
  processingType: PdfProcessingType
): Promise<{
  summary: string | null;
  questions: PdfQuestion[] | null;
  quiz: PdfQuiz | null;
  flashcards: PdfFlashcard[] | null;
}> {
  const { aiGateway } = await import('../modules/ai/ai.service.js');

  const results: {
    summary: string | null;
    questions: PdfQuestion[] | null;
    quiz: PdfQuiz | null;
    flashcards: PdfFlashcard[] | null;
  } = {
    summary: null,
    questions: null,
    quiz: null,
    flashcards: null,
  };

  const doAll = processingType === 'all';

  // ── Summarize ─────────────────────────────────────────────────────────────
  if (doAll || processingType === 'summarize') {
    try {
      const prompt =
        `You are an expert academic summarizer. Read the following document content and produce a comprehensive, ` +
        `well-structured summary in the same language as the content.\n\n` +
        `Document: "${filename}"\n\nContent:\n${text}\n\n` +
        `Write a clear, organized summary with key points, main arguments, and important conclusions. ` +
        `Use bullet points or numbered lists where appropriate. Be thorough but concise.`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      results.summary = result.text;
      logger.info(`[PdfProcessor] Summary generated (${result.text.length} chars)`);
    } catch (err: any) {
      logger.warn(`[PdfProcessor] Summarization failed: ${err.message}`);
    }
  }

  // ── Generate Study Questions ───────────────────────────────────────────────
  if (doAll || processingType === 'questions') {
    try {
      const prompt =
        `Based on the following document, generate exactly 10 academic study questions with detailed answers. ` +
        `Respond ONLY with valid JSON in this exact format:\n` +
        `[{"question":"...","answer":"...","type":"short_answer"}]\n\n` +
        `Use "short_answer" or "discussion" for the type field.\n\n` +
        `Document: "${filename}"\n\nContent:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '[');
      results.questions = JSON.parse(clean) as PdfQuestion[];
      logger.info(`[PdfProcessor] ${results.questions.length} questions generated`);
    } catch (err: any) {
      logger.warn(`[PdfProcessor] Question generation failed: ${err.message}`);
    }
  }

  // ── Generate Quiz ─────────────────────────────────────────────────────────
  if (doAll || processingType === 'quiz') {
    try {
      const prompt =
        `Based on the following document, create an academic quiz with 10 multiple-choice questions. ` +
        `Respond ONLY with valid JSON in this exact format:\n` +
        `{"title":"Quiz Title","questions":[{"questionText":"...","type":"multiple_choice","options":["A","B","C","D"],"correctAnswer":"A","explanation":"..."}]}\n\n` +
        `Document: "${filename}"\n\nContent:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '{');
      results.quiz = JSON.parse(clean) as PdfQuiz;
      logger.info(`[PdfProcessor] Quiz generated (${results.quiz.questions?.length ?? 0} questions)`);
    } catch (err: any) {
      logger.warn(`[PdfProcessor] Quiz generation failed: ${err.message}`);
    }
  }

  // ── Generate Flashcards ───────────────────────────────────────────────────
  if (doAll || processingType === 'flashcards') {
    try {
      const prompt =
        `Based on the following document, create 15 study flashcards covering the key concepts, terms, and facts. ` +
        `Respond ONLY with valid JSON in this exact format:\n` +
        `[{"front":"Term or question","back":"Definition or answer"}]\n\n` +
        `Document: "${filename}"\n\nContent:\n${text}`;

      const result = await aiGateway.chatWithTeacher(userId, prompt);
      const clean = extractJson(result.text, '[');
      results.flashcards = JSON.parse(clean) as PdfFlashcard[];
      logger.info(`[PdfProcessor] ${results.flashcards.length} flashcards generated`);
    } catch (err: any) {
      logger.warn(`[PdfProcessor] Flashcard generation failed: ${err.message}`);
    }
  }

  return results;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Extract JSON substring starting at the first occurrence of `startChar` */
function extractJson(text: string, startChar: '{' | '['): string {
  let clean = text.replace(/```json/g, '').replace(/```/g, '').trim();
  const startIdx = clean.indexOf(startChar);
  if (startIdx > 0) {
    clean = clean.slice(startIdx);
  }
  return clean;
}

async function updateJobStatus(jobId: string, status: 'processing' | 'completed'): Promise<void> {
  await supabaseAdmin.from('pdf_jobs').update({ status }).eq('id', jobId);
}

async function failJob(jobId: string, errorMessage: string): Promise<void> {
  await supabaseAdmin
    .from('pdf_jobs')
    .update({
      status: 'failed',
      error_message: errorMessage.slice(0, 2000), // cap to DB column limit
    })
    .eq('id', jobId);
}

/**
 * Legacy export — kept for backward compatibility with existing worker imports.
 * @deprecated Use processPdfAiJob instead.
 */
export async function processPdfJob(data: { lectureId: string; fileUrl: string }): Promise<void> {
  const { lectureId, fileUrl } = data;
  logger.info(`[PdfProcessor:legacy] Starting text extraction for lecture: ${lectureId}`);

  validateExternalUrl(fileUrl);

  const response = await axios.get<ArrayBuffer>(fileUrl, {
    responseType: 'arraybuffer',
    timeout: 15000,
    maxContentLength: 25 * 1024 * 1024,
  });
  const buffer = Buffer.from(response.data);

  const magicCheck = validateMagicBytes(buffer);
  if (!magicCheck.isValid || magicCheck.detectedType !== 'application/pdf') {
    throw new Error('Invalid PDF document: Magic bytes do not match genuine PDF structure');
  }

  const parsed = await pdfParse(buffer);
  const extractedText = parsed.text || '';

  await supabaseAdmin
    .from('lectures')
    .update({ extracted_text: extractedText, is_processed: true })
    .eq('id', lectureId);

  logger.info(`[PdfProcessor:legacy] Extracted ${extractedText.length} chars for lecture ${lectureId}`);
}
