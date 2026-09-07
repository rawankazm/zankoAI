// ==============================================================================
// ZankoAI Quiz & Flashcard Input Validators & Question Sanity Checker
// ==============================================================================

import { z } from 'zod';
import { BadRequestError } from '../utils/apiError.js';
import type { QuizQuestionType, QuizDifficulty, RawQuizQuestion } from '../types/quiz.types.js';

/**
 * Strictly validates a single question to prevent malformed or un-gradable questions.
 * Throws BadRequestError with precise actionable reason if invalid.
 */
export function validateAndNormalizeQuestion(q: any, index: number = 1): RawQuizQuestion {
  if (!q || typeof q !== 'object') {
    throw new BadRequestError(`Question #${index} is malformed: must be a valid object`);
  }

  // 1. Question Text validation
  const questionText = String(q.question_text || q.questionText || '').trim();
  if (questionText.length < 5) {
    throw new BadRequestError(
      `Question #${index} has invalid or empty question_text (minimum 5 characters required)`
    );
  }

  // 2. Question Type validation
  let rawType = String(q.question_type || q.questionType || 'multiple_choice').toLowerCase().trim();
  if (rawType === 'mcq' || rawType === 'multiplechoice') rawType = 'multiple_choice';
  if (rawType === 'tf' || rawType === 'truefalse') rawType = 'true_false';
  if (rawType === 'shortanswer' || rawType === 'fill_in_blank') rawType = 'short_answer';

  if (!['multiple_choice', 'true_false', 'short_answer'].includes(rawType)) {
    throw new BadRequestError(
      `Question #${index} has unsupported question_type: "${rawType}". Must be multiple_choice, true_false, or short_answer.`
    );
  }
  const question_type = rawType as QuizQuestionType;

  // 3. Correct Answer validation
  const correctAnswer = String(q.correct_answer || q.correctAnswer || '').trim();
  if (!correctAnswer) {
    throw new BadRequestError(
      `Question #${index} is missing a required correct_answer`
    );
  }

  // 4. Options validation based on question type
  let options: string[] = [];

  if (question_type === 'multiple_choice') {
    const rawOptions = Array.isArray(q.options) ? q.options : [];
    options = rawOptions.map((opt: any) => String(opt || '').trim()).filter((opt: string) => opt.length > 0);

    if (options.length < 2) {
      throw new BadRequestError(
        `Multiple choice question #${index} must provide at least 2 distinct options (received ${options.length})`
      );
    }
    if (options.length > 8) {
      throw new BadRequestError(
        `Multiple choice question #${index} cannot have more than 8 options (received ${options.length})`
      );
    }

    // Crucial: Correct answer must be one of the provided options!
    const answerInOptions = options.some(
      (opt) => opt.toLowerCase() === correctAnswer.toLowerCase()
    );
    if (!answerInOptions) {
      throw new BadRequestError(
        `Question #${index} error: correct_answer "${correctAnswer}" is not among the provided options: [${options.join(', ')}]`
      );
    }
  } else if (question_type === 'true_false') {
    const normAns = correctAnswer.toLowerCase();
    const validTfAnswers = ['true', 'false', 'ڕاست', 'هەڵە', 'صحیح', 'خطأ'];
    if (!validTfAnswers.includes(normAns)) {
      throw new BadRequestError(
        `True/False question #${index} must have correct_answer as True/False (received "${correctAnswer}")`
      );
    }
    options = ['True', 'False'];
  } else if (question_type === 'short_answer') {
    options = [];
  }

  // 5. Difficulty validation
  const rawDiff = String(q.difficulty || 'medium').toLowerCase().trim();
  const difficulty: QuizDifficulty = ['easy', 'medium', 'hard', 'advanced'].includes(rawDiff)
    ? (rawDiff as QuizDifficulty)
    : 'medium';

  // 6. Points
  const points = typeof q.points === 'number' && q.points > 0 ? q.points : 1;

  // 7. Explanation
  const explanation = q.explanation ? String(q.explanation).trim() : undefined;

  return {
    question_text: questionText,
    question_type,
    options,
    correct_answer: correctAnswer,
    explanation,
    difficulty,
    points,
    order_index: typeof q.order_index === 'number' ? q.order_index : index - 1,
  };
}

/**
 * Validates a batch of questions and guarantees that at least 1 valid question exists.
 */
export function validateQuestionList(rawQuestions: any[]): RawQuizQuestion[] {
  if (!Array.isArray(rawQuestions) || rawQuestions.length === 0) {
    throw new BadRequestError('Quiz must contain at least one question');
  }

  return rawQuestions.map((q, idx) => validateAndNormalizeQuestion(q, idx + 1));
}

// ─── Zod Schemas for API Endpoints ───

export const createQuizSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters').max(200),
  course_id: z.string().uuid('Invalid course ID').optional().nullable(),
  description: z.string().max(1000).optional(),
  source_type: z.enum(['pdf', 'ocr', 'lecture', 'teacher', 'ai_topic', 'manual']).default('manual'),
  source_id: z.string().uuid('Invalid source ID').optional().nullable(),
  difficulty: z.enum(['easy', 'medium', 'hard', 'advanced']).default('medium'),
  time_limit_minutes: z.number().int().min(1).max(180).default(30),
  passing_score: z.number().min(0).max(100).default(50),
  is_published: z.boolean().default(true),
  questions: z.array(z.any()).optional(),
  ai_generation: z
    .object({
      source_text: z.string().max(30000).optional(),
      topic: z.string().max(300).optional(),
      course_name: z.string().max(200).optional(),
      question_count: z.number().int().min(1).max(30).default(5),
      difficulty: z.enum(['easy', 'medium', 'hard', 'advanced']).default('medium'),
      question_types: z.array(z.enum(['multiple_choice', 'true_false', 'short_answer'])).optional(),
    })
    .optional(),
});

export const submitQuizAttemptSchema = z.object({
  attempt_id: z.string().uuid('Invalid attempt ID format'),
  time_spent_seconds: z.number().int().min(0).default(0),
  answers: z.array(
    z.object({
      question_id: z.string().uuid('Invalid question ID format'),
      selected_answer: z.string().max(1000),
    })
  ),
});

export const reviewFlashcardSchema = z.object({
  rating: z.number().int().min(0).max(5, 'Rating must be an integer between 0 and 5'),
});
