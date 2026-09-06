import { z } from 'zod';

// ─── Lectures ───
export const createLectureSchema = z.object({
  course_id: z.string().uuid(),
  title: z.string().min(2).max(200),
  title_ku: z.string().max(200).optional(),
  content: z.string().optional(),
  file_url: z.string().url().optional().or(z.literal('')),
  file_type: z.string().max(50).optional(),
  order_index: z.number().int().min(0).default(0),
  duration_minutes: z.number().int().positive().optional(),
  is_published: z.boolean().default(true),
});

export const updateLectureSchema = createLectureSchema.partial();

// ─── Assignments ───
export const createAssignmentSchema = z.object({
  course_id: z.string().uuid(),
  title: z.string().min(3).max(200),
  description: z.string().max(2000).optional(),
  due_date: z.string().datetime(),
  max_score: z.number().positive().default(100),
  attachment_url: z.string().url().optional().or(z.literal('')),
  is_published: z.boolean().default(true),
});

export const updateAssignmentSchema = createAssignmentSchema.partial();

// ─── Assignment Submissions ───
export const submitAssignmentSchema = z.object({
  content: z.string().max(5000).optional(),
  file_url: z.string().url().optional().or(z.literal('')),
});

export const gradeSubmissionSchema = z.object({
  score: z.number().min(0),
  feedback: z.string().max(1000).optional(),
  status: z.enum(['submitted', 'graded', 'late', 'resubmitted']).default('graded'),
});

// ─── Quizzes ───
export const createQuizSchema = z.object({
  course_id: z.string().uuid(),
  title: z.string().min(3).max(200),
  description: z.string().max(1000).optional(),
  time_limit_minutes: z.number().int().positive().default(30),
  passing_score: z.number().min(0).max(100).default(50),
  is_published: z.boolean().default(true),
});

export const updateQuizSchema = createQuizSchema.partial();

export const createQuizQuestionSchema = z.object({
  quiz_id: z.string().uuid(),
  question_text: z.string().min(3),
  question_type: z.enum(['multiple_choice', 'true_false', 'short_answer']).default('multiple_choice'),
  options: z.array(z.string()).default([]),
  correct_answer: z.string().min(1),
  explanation: z.string().optional(),
  points: z.number().positive().default(1),
  order_index: z.number().int().min(0).default(0),
});

export const submitQuizAttemptSchema = z.object({
  answers: z.array(
    z.object({
      question_id: z.string().uuid(),
      selected_answer: z.string(),
    })
  ),
});

// ─── Flashcards ───
export const createFlashcardSchema = z.object({
  course_id: z.string().uuid().optional(),
  deck_name: z.string().min(1).max(100).default('General'),
  front_text: z.string().min(1).max(1000),
  back_text: z.string().min(1).max(1000),
  hint: z.string().max(300).optional(),
  is_public: z.boolean().default(true),
});

export const updateFlashcardSchema = createFlashcardSchema.partial();
