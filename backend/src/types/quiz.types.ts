// ==============================================================================
// ZankoAI Quiz & Flashcard TypeScript Type Definitions
// ==============================================================================

export type QuizQuestionType = 'multiple_choice' | 'true_false' | 'short_answer';

export type QuizSourceType = 'pdf' | 'ocr' | 'lecture' | 'teacher' | 'ai_topic' | 'manual';

export type QuizDifficulty = 'easy' | 'medium' | 'hard' | 'advanced';

export interface RawQuizQuestion {
  id?: string;
  quiz_id?: string;
  question_text: string;
  question_type: QuizQuestionType;
  options?: string[];
  correct_answer: string;
  explanation?: string;
  difficulty?: QuizDifficulty;
  points?: number;
  order_index?: number;
}

export interface SanitizedQuizQuestion {
  id: string;
  quiz_id: string;
  question_text: string;
  question_type: QuizQuestionType;
  options: string[];
  difficulty: QuizDifficulty;
  points: number;
  order_index: number;
  // correct_answer and explanation omitted for students during test taking!
}

export interface QuizQuestionRecord extends RawQuizQuestion {
  id: string;
  quiz_id: string;
  options: string[];
  correct_answer: string;
  explanation: string;
  difficulty: QuizDifficulty;
  points: number;
  order_index: number;
  created_at: string;
  updated_at: string;
}

export interface QuizRecord {
  id: string;
  course_id: string | null;
  creator_id: string;
  title: string;
  description?: string;
  source_type: QuizSourceType;
  source_id?: string | null;
  difficulty: QuizDifficulty;
  time_limit_minutes: number;
  passing_score: number;
  is_published: boolean;
  question_count: number;
  created_at: string;
  updated_at: string;
  questions?: QuizQuestionRecord[] | SanitizedQuizQuestion[];
}

export interface CreateQuizDto {
  title: string;
  course_id?: string | null;
  description?: string;
  source_type?: QuizSourceType;
  source_id?: string | null;
  difficulty?: QuizDifficulty;
  time_limit_minutes?: number;
  passing_score?: number;
  is_published?: boolean;
  questions?: RawQuizQuestion[];
  ai_generation?: {
    source_text?: string;
    topic?: string;
    course_name?: string;
    question_count?: number;
    difficulty?: QuizDifficulty;
    question_types?: QuizQuestionType[];
  };
}

export interface StartQuizAttemptResult {
  attempt_id: string;
  quiz_id: string;
  title: string;
  time_limit_minutes: number;
  started_at: string;
  question_count: number;
  questions: SanitizedQuizQuestion[];
}

export interface SubmittedQuestionAnswer {
  question_id: string;
  selected_answer: string;
}

export interface SubmitQuizAttemptDto {
  attempt_id: string;
  time_spent_seconds?: number;
  answers: SubmittedQuestionAnswer[];
}

export interface EvaluatedAnswer {
  question_id: string;
  question_text: string;
  question_type: QuizQuestionType;
  selected_answer: string;
  correct_answer: string;
  is_correct: boolean;
  points_awarded: number;
  max_points: number;
  explanation?: string;
}

export interface QuizSubmissionResult {
  attempt_id: string;
  quiz_id: string;
  user_id: string;
  score: number;
  total_points: number;
  percentage: number;
  passed: boolean;
  passing_score: number;
  started_at: string;
  completed_at: string;
  time_spent_seconds: number;
  evaluated_answers: EvaluatedAnswer[];
}

// ─── Flashcard Types ───

export interface FlashcardRecord {
  id: string;
  course_id?: string | null;
  creator_id: string;
  deck_name: string;
  front_text: string;
  back_text: string;
  hint?: string;
  source_type: QuizSourceType;
  difficulty: QuizDifficulty;
  is_public: boolean;
  created_at: string;
  updated_at: string;
}

export interface FlashcardProgressRecord {
  id: string;
  flashcard_id: string;
  user_id: string;
  box: number;
  ease_factor: number;
  interval_days: number;
  repetitions: number;
  next_review_at: string;
  last_reviewed_at: string | null;
}

export interface ReviewFlashcardDto {
  rating: number; // 0 (complete blackout) to 5 (perfect recall)
}

export interface SM2ReviewResult {
  box: number;
  ease_factor: number;
  interval_days: number;
  repetitions: number;
  next_review_at: string;
}
