// ==============================================================================
// ZankoAI PDF AI Processing Types
// ==============================================================================

export type PdfJobStatus = 'queued' | 'processing' | 'completed' | 'failed';

export type PdfProcessingType = 'all' | 'summarize' | 'quiz' | 'flashcards' | 'questions';

// ─── Database Row Interfaces ──────────────────────────────────────────────────

export interface PdfJob {
  id: string;
  user_id: string;
  idempotency_key: string;
  original_filename: string;
  storage_path: string;        // internal — never sent to clients
  file_size_bytes: number;
  page_count: number;
  processing_type: PdfProcessingType;
  status: PdfJobStatus;
  error_message: string | null;
  bullmq_job_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface PdfJobResult {
  id: string;
  job_id: string;
  user_id: string;
  summary: string | null;
  questions: PdfQuestion[] | null;
  quiz: PdfQuiz | null;
  flashcards: PdfFlashcard[] | null;
  extracted_text_length: number;
  created_at: string;
}

// ─── AI Output Shape Interfaces ───────────────────────────────────────────────

export interface PdfQuestion {
  question: string;
  answer: string;
  type: 'short_answer' | 'discussion';
}

export interface PdfQuizItem {
  questionText: string;
  type: 'multiple_choice' | 'true_false';
  options: string[];
  correctAnswer: string;
  explanation: string;
}

export interface PdfQuiz {
  title: string;
  questions: PdfQuizItem[];
}

export interface PdfFlashcard {
  front: string;
  back: string;
}

// ─── Request / Response DTOs ─────────────────────────────────────────────────

export interface SubmitPdfJobRequest {
  processingType: PdfProcessingType;
  idempotencyKey?: string;
}

/**
 * Safe job status response — never includes raw storage_path or signed URLs.
 */
export interface PdfJobStatusResponse {
  jobId: string;
  status: PdfJobStatus;
  originalFilename: string;
  fileSizeBytes: number;
  pageCount: number;
  processingType: PdfProcessingType;
  errorMessage: string | null;
  createdAt: string;
  updatedAt: string;
  /** Present only when status === 'completed' */
  result?: {
    summary: string | null;
    questions: PdfQuestion[] | null;
    quiz: PdfQuiz | null;
    flashcards: PdfFlashcard[] | null;
    extractedTextLength: number;
  };
  /** Quota info from enforceUsage */
  usage?: {
    remaining: number;
    limit: number;
    resetAt: string;
  };
}

export interface AskPdfRequest {
  jobId: string;
  question: string;
}

export interface AskPdfResponse {
  answer: string;
  jobId: string;
}

// ─── BullMQ Job Data ─────────────────────────────────────────────────────────

export interface PdfAiJobData {
  jobId: string;         // pdf_jobs.id
  userId: string;
  storagePath: string;   // Supabase Storage path (internal)
  processingType: PdfProcessingType;
  originalFilename: string;
}
