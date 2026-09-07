// ==============================================================================
// ZankoAI OCR AI Processing Types
// ==============================================================================

export type OcrType = 'auto' | 'printed' | 'handwriting';

export type OcrProcessingType =
  | 'extract_only'
  | 'all'
  | 'summarize'
  | 'quiz'
  | 'flashcards'
  | 'questions';

export type OcrJobStatus = 'queued' | 'processing' | 'completed' | 'failed';

export type DetectedTextType = 'handwriting' | 'printed' | 'mixed';

export interface OcrQuestion {
  id: string;
  question: string;
  answer: string;
  contextSnippet?: string;
}

export interface OcrQuizQuestion {
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

export interface OcrQuiz {
  title: string;
  questions: OcrQuizQuestion[];
}

export interface OcrFlashcard {
  id: string;
  front: string;
  back: string;
}

export interface OcrJobResult {
  id: string;
  jobId: string;
  userId: string;
  extractedText: string;
  detectedTextType: DetectedTextType;
  confidenceScore: number;
  summary?: string | null;
  questions?: OcrQuestion[];
  quiz?: OcrQuiz;
  flashcards?: OcrFlashcard[];
  ocrProvider: string;
  extractedTextLength: number;
  createdAt: string;
}

export interface OcrJob {
  id: string;
  userId: string;
  idempotencyKey: string;
  originalFilename: string;
  storagePath: string;
  fileSizeBytes: number;
  imageWidth: number;
  imageHeight: number;
  ocrType: OcrType;
  processingType: OcrProcessingType;
  status: OcrJobStatus;
  errorMessage?: string | null;
  bullmqJobId?: string | null;
  createdAt: string;
  updatedAt: string;
  result?: OcrJobResult;
}

/** BullMQ worker job data payload */
export interface OcrAiJobData {
  jobId: string;
  userId: string;
  storagePath: string;
  originalFilename: string;
  ocrType: OcrType;
  processingType: OcrProcessingType;
  imageWidth: number;
  imageHeight: number;
  fileSizeBytes: number;
}

/** API response returned by GET /api/ai/ocr/:jobId and POST /api/ai/ocr */
export interface OcrJobStatusResponse {
  jobId: string;
  status: OcrJobStatus;
  originalFilename: string;
  fileSizeBytes: number;
  imageWidth: number;
  imageHeight: number;
  ocrType: OcrType;
  processingType: OcrProcessingType;
  createdAt: string;
  updatedAt: string;
  errorMessage?: string | null;
  result?: {
    extractedText: string;
    detectedTextType: DetectedTextType;
    confidenceScore: number;
    extractedTextLength: number;
    summary?: string | null;
    questions?: OcrQuestion[];
    quiz?: OcrQuiz;
    flashcards?: OcrFlashcard[];
    ocrProvider: string;
  };
}

export interface OcrExtractionOptions {
  mode?: OcrType;
  languageHint?: string;
}

export interface OcrExtractionResult {
  rawText: string;
  cleanedText: string;
  detectedType: DetectedTextType;
  confidence: number;
  languageDetected?: string;
  provider: string;
}
