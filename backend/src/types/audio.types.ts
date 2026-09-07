// ==============================================================================
// ZankoAI Teacher Lecture Audio Recorder & Processing Types
// ==============================================================================

export type AudioJobStatus =
  | 'queued'
  | 'processing'
  | 'transcribing'
  | 'summarizing'
  | 'generating'
  | 'completed'
  | 'failed';

export interface AudioFlashcard {
  id: string;
  front: string;
  back: string;
}

export interface AudioQuizQuestion {
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

export interface AudioQuiz {
  title: string;
  questions: AudioQuizQuestion[];
}

export interface LectureAudioResult {
  id: string;
  jobId: string;
  courseId: string;
  transcript: string;
  summary: string;
  keyTakeaways: string[];
  flashcards: AudioFlashcard[];
  quiz: AudioQuiz;
  languageDetected: string;
  createdAt: string;
}

export interface LectureAudioJob {
  id: string;
  teacherId: string;
  courseId: string;
  lectureId?: string | null;
  title: string;
  storagePath: string;
  fileSizeBytes: number;
  durationSeconds: number;
  audioFormat: string;
  idempotencyKey: string;
  status: AudioJobStatus;
  isPublished: boolean;
  errorMessage?: string | null;
  bullmqJobId?: string | null;
  createdAt: string;
  updatedAt: string;
  result?: LectureAudioResult;
}

/** BullMQ worker job data payload */
export interface LectureAudioJobData {
  jobId: string;
  teacherId: string;
  courseId: string;
  lectureId?: string | null;
  title: string;
  storagePath: string;
  audioFormat: string;
  fileSizeBytes: number;
  languageHint?: string;
}

/** API response returned to clients */
export interface LectureAudioResponseDto {
  jobId: string;
  status: AudioJobStatus;
  courseId: string;
  lectureId?: string | null;
  title: string;
  fileSizeBytes: number;
  durationSeconds: number;
  audioFormat: string;
  isPublished: boolean;
  createdAt: string;
  updatedAt: string;
  errorMessage?: string | null;
  result?: {
    transcript: string;
    summary: string;
    keyTakeaways: string[];
    flashcards: AudioFlashcard[];
    quiz: AudioQuiz;
    languageDetected: string;
  };
}
