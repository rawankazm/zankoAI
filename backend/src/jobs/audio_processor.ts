import axios from 'axios';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { validateExternalUrl } from '../utils/ssrfValidator.js';
import { validateAudioMagicBytes } from '../utils/audio_format_validator.js';
import { GeminiAudioProvider } from '../modules/ai/providers/audio/gemini_audio.provider.js';
import {
  LectureAudioJobData,
  AudioJobStatus,
  AudioFlashcard,
  AudioQuiz,
} from '../types/audio.types.js';

/** Maximum download size for lecture audio (50 MB) */
const MAX_DOWNLOAD_SIZE = 50 * 1024 * 1024;

/** Minimum speech transcript length */
const MIN_TRANSCRIPT_LENGTH = 10;

/** Maximum text characters passed to downstream AI generation */
const MAX_TEXT_FOR_AI = 15000;

export async function processAudioLectureJob(data: LectureAudioJobData): Promise<void> {
  const { jobId, teacherId, courseId, title, storagePath, audioFormat, languageHint } = data;

  logger.info(`[AudioProcessor] Starting audio lecture job ${jobId} (title="${title}", course=${courseId})`);

  // ── 1. Mark as processing ───────────────────────────────────────────────────
  await updateJobStatus(jobId, 'processing');

  let signedUrl: string;

  try {
    const { AudioService } = await import('../modules/ai/audio.service.js');
    signedUrl = await AudioService.createInternalSignedUrl(storagePath);
  } catch (err: any) {
    logger.error(`[AudioProcessor] Failed to create signed URL for job ${jobId}: ${err.message}`);
    await failJob(jobId, `Storage access failed: ${err.message}`);
    throw err;
  }

  let buffer: Buffer;

  try {
    // ── 2. Download with SSRF protection ─────────────────────────────────────
    validateExternalUrl(signedUrl);

    const response = await axios.get<ArrayBuffer>(signedUrl, {
      responseType: 'arraybuffer',
      timeout: 45_000,
      maxContentLength: MAX_DOWNLOAD_SIZE,
    });
    buffer = Buffer.from(response.data);
  } catch (err: any) {
    logger.error(`[AudioProcessor] Download failed for job ${jobId}: ${err.message}`);
    await failJob(jobId, `Audio download failed: ${err.message}`);
    throw err;
  }

  try {
    // ── 3. Validate Audio Magic Bytes ─────────────────────────────────────────
    const audioCheck = validateAudioMagicBytes(buffer);
    if (!audioCheck.isValid) {
      throw new Error('Downloaded audio failed binary signature check (corrupt or invalid audio format).');
    }

    // ── 4. Transcribe Audio (Speech-to-Text) ──────────────────────────────────
    await updateJobStatus(jobId, 'transcribing');
    logger.info(`[AudioProcessor] Job ${jobId} transitioning to 'transcribing'...`);

    const audioProvider = new GeminiAudioProvider();
    const mimeType = audioCheck.detectedMime || audioFormat || 'audio/mp4';
    const transcriptionResult = await audioProvider.transcribeAudio(
      buffer,
      mimeType,
      languageHint || 'ku'
    );

    const transcript = transcriptionResult.transcript.trim();
    if (transcript.length < MIN_TRANSCRIPT_LENGTH) {
      throw new Error(
        `Speech-to-text produced insufficient transcript (${transcript.length} characters). Audio might be silent or unclear.`
      );
    }

    logger.info(`[AudioProcessor] Job ${jobId}: transcribed ${transcript.length} chars.`);

    // Truncate if exceptionally long for downstream prompts
    const promptText = transcript.length > MAX_TEXT_FOR_AI ? transcript.substring(0, MAX_TEXT_FOR_AI) : transcript;

    // ── 5. Summarize (Academic Summary & Key Takeaways) ───────────────────────
    await updateJobStatus(jobId, 'summarizing');
    logger.info(`[AudioProcessor] Job ${jobId} transitioning to 'summarizing'...`);

    const { aiGateway } = await import('../modules/ai/ai.service.js');

    const summaryPrompt =
      `You are an expert university professor and pedagogical summarizer. ` +
      `Below is the complete verbatim transcript of a recorded lecture titled "${title}".\n\n` +
      `Lecture Transcript:\n${promptText}\n\n` +
      `Create a thorough, comprehensive academic summary structured with:\n` +
      `1. Executive Lecture Summary\n` +
      `2. Main Concepts and Explanations\n` +
      `3. Formulas / Algorithms / Key Rules\n` +
      `4. Conclusion and Review Points\n\n` +
      `Write in the same language as the lecture (Kurdish, Arabic, or English).`;

    const summaryRes = await aiGateway.chatWithTeacher(teacherId, summaryPrompt);
    const summary = summaryRes.text;

    const takeawaysPrompt =
      `From the following lecture transcript, extract 5 to 10 crucial key takeaways or examination points. ` +
      `Respond ONLY with a valid JSON array of strings: ["point 1", "point 2", ...]\n\n` +
      `Transcript:\n${promptText}`;

    let keyTakeaways: string[] = [];
    try {
      const takeawaysRes = await aiGateway.chatWithTeacher(teacherId, takeawaysPrompt);
      const cleanJson = extractJson(takeawaysRes.text, '[');
      keyTakeaways = JSON.parse(cleanJson) as string[];
    } catch (err: any) {
      logger.warn(`[AudioProcessor] Key takeaways extraction warning: ${err.message}`);
    }

    // ── 6. Generating Study Aids (Flashcards & Quiz) ──────────────────────────
    await updateJobStatus(jobId, 'generating');
    logger.info(`[AudioProcessor] Job ${jobId} transitioning to 'generating'...`);

    // Flashcards
    const flashcardsPrompt =
      `Based on this lecture transcript, create 10 to 15 high-yield study flashcards covering key definitions, principles, and terms. ` +
      `Respond ONLY with valid JSON in this exact format:\n` +
      `[{"id":"1","front":"Key term or question","back":"Clear concise definition or explanation"}]\n\n` +
      `Transcript:\n${promptText}`;

    let flashcards: AudioFlashcard[] = [];
    try {
      const fcRes = await aiGateway.chatWithTeacher(teacherId, flashcardsPrompt);
      const cleanJson = extractJson(fcRes.text, '[');
      flashcards = JSON.parse(cleanJson) as AudioFlashcard[];
    } catch (err: any) {
      logger.warn(`[AudioProcessor] Flashcard generation warning: ${err.message}`);
    }

    // Quiz
    const quizPrompt =
      `Based on this lecture transcript, create a university-level quiz with 5 to 10 multiple-choice questions. ` +
      `Respond ONLY with valid JSON in this exact format:\n` +
      `{"title":"Quiz: ${title}","questions":[{"question":"...","options":["A","B","C","D"],"correctAnswer":0,"explanation":"..."}]}\n\n` +
      `Transcript:\n${promptText}`;

    let quiz: AudioQuiz = { title: `Quiz: ${title}`, questions: [] };
    try {
      const quizRes = await aiGateway.chatWithTeacher(teacherId, quizPrompt);
      const cleanJson = extractJson(quizRes.text, '{');
      quiz = JSON.parse(cleanJson) as AudioQuiz;
    } catch (err: any) {
      logger.warn(`[AudioProcessor] Quiz generation warning: ${err.message}`);
    }

    // ── 7. Save Results ───────────────────────────────────────────────────────
    const { error: insertError } = await supabaseAdmin.from('lecture_audio_results').insert({
      job_id: jobId,
      course_id: courseId,
      transcript,
      summary,
      key_takeaways: keyTakeaways,
      flashcards,
      quiz,
      language_detected: transcriptionResult.languageDetected || 'ku',
    });

    if (insertError) {
      throw new Error(`Failed to persist lecture audio results: ${insertError.message}`);
    }

    // ── 8. Mark as Completed ──────────────────────────────────────────────────
    await updateJobStatus(jobId, 'completed');
    logger.info(`[AudioProcessor] Job ${jobId} completed successfully.`);
  } catch (err: any) {
    logger.error(`[AudioProcessor] Job ${jobId} failed: ${err.message}`);
    await failJob(jobId, err.message);
    throw err;
  }
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

async function updateJobStatus(jobId: string, status: AudioJobStatus): Promise<void> {
  const { error } = await supabaseAdmin
    .from('lecture_audio_jobs')
    .update({ status })
    .eq('id', jobId);

  if (error) {
    logger.error(`[AudioProcessor] Failed to update status to '${status}' for job ${jobId}: ${error.message}`);
  }
}

async function failJob(jobId: string, errorMessage: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from('lecture_audio_jobs')
    .update({
      status: 'failed',
      error_message: errorMessage,
    })
    .eq('id', jobId);

  if (error) {
    logger.error(`[AudioProcessor] Failed to mark job ${jobId} as failed: ${error.message}`);
  }
}
