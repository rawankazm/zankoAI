// ==============================================================================
// ZankoAI Quiz & Flashcard Service
// ==============================================================================

import { GoogleGenAI } from '@google/genai';
import { supabaseAdmin } from '../config/supabase.js';
import { env } from '../config/env.js';
import { logger } from '../config/logger.js';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
} from '../utils/apiError.js';
import {
  validateQuestionList,
  validateAndNormalizeQuestion,
} from '../validators/quiz.validators.js';
import { cleanMathAndDollarSigns } from '../modules/ai/ai.service.js';
import type {
  CreateQuizDto,
  RawQuizQuestion,
  SanitizedQuizQuestion,
  QuizRecord,
  StartQuizAttemptResult,
  SubmitQuizAttemptDto,
  QuizSubmissionResult,
  EvaluatedAnswer,
  SM2ReviewResult,
} from '../types/quiz.types.js';

export class QuizService {
  private static geminiClient?: GoogleGenAI;

  private static getGeminiClient(): GoogleGenAI | undefined {
    if (!this.geminiClient && env.GEMINI_API_KEY) {
      this.geminiClient = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
    }
    return this.geminiClient;
  }

  /**
   * 1. Create a quiz manually or by generating questions from AI source
   */
  static async createQuiz(
    callerId: string,
    callerRole: string,
    dto: CreateQuizDto
  ): Promise<QuizRecord> {
    // A. Course Authorization Check
    if (dto.course_id) {
      if (callerRole !== 'admin' && callerRole !== 'teacher') {
        throw new ForbiddenError('Only teachers and administrators can create course quizzes');
      }

      // If caller is teacher, verify course instructor assignment
      if (callerRole === 'teacher') {
        const { data: member } = await supabaseAdmin
          .from('course_members')
          .select('role')
          .eq('course_id', dto.course_id)
          .eq('user_id', callerId)
          .maybeSingle();

        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('instructor_id')
          .eq('id', dto.course_id)
          .maybeSingle();

        const isInstructor = course?.instructor_id === callerId;
        const isTeacherMember = member?.role === 'teacher' || member?.role === 'instructor';

        if (!isInstructor && !isTeacherMember) {
          throw new ForbiddenError('You are not an authorized instructor for this course');
        }
      }
    }

    let finalQuestions: RawQuizQuestion[] = [];

    // B. AI Generation from Source (PDF, OCR, Lecture, Topic, Teacher content)
    if (dto.ai_generation) {
      finalQuestions = await this.generateQuestionsWithAI(dto.ai_generation, dto.source_type);
    } else if (dto.questions && dto.questions.length > 0) {
      finalQuestions = validateQuestionList(dto.questions);
    } else {
      throw new BadRequestError('You must provide either manual questions or ai_generation parameters');
    }

    // C. Insert Quiz Master Record
    const { data: quiz, error: quizError } = await supabaseAdmin
      .from('quizzes')
      .insert({
        course_id: dto.course_id || null,
        creator_id: callerId,
        title: cleanMathAndDollarSigns(dto.title),
        description: dto.description ? cleanMathAndDollarSigns(dto.description) : null,
        source_type: dto.source_type || 'manual',
        source_id: dto.source_id || null,
        difficulty: dto.difficulty || 'medium',
        time_limit_minutes: dto.time_limit_minutes || 30,
        passing_score: dto.passing_score ?? 50,
        is_published: dto.is_published ?? true,
        question_count: finalQuestions.length,
      })
      .select()
      .maybeSingle();

    if (quizError || !quiz) {
      logger.error('[QuizService] Failed to insert quiz record:', quizError);
      throw new BadRequestError('Failed to create quiz record in database');
    }

    // D. Insert Questions
    const questionsToInsert = finalQuestions.map((q, idx) => ({
      quiz_id: quiz.id,
      question_text: cleanMathAndDollarSigns(q.question_text),
      question_type: q.question_type,
      options: q.options ? q.options.map((opt) => cleanMathAndDollarSigns(opt)) : [],
      correct_answer: cleanMathAndDollarSigns(q.correct_answer),
      explanation: q.explanation ? cleanMathAndDollarSigns(q.explanation) : null,
      difficulty: q.difficulty || quiz.difficulty,
      points: q.points || 1,
      order_index: idx,
    }));

    const { data: insertedQuestions, error: questionsError } = await supabaseAdmin
      .from('quiz_questions')
      .insert(questionsToInsert)
      .select();

    if (questionsError) {
      logger.error('[QuizService] Failed to insert quiz questions:', questionsError);
      await supabaseAdmin.from('quizzes').delete().eq('id', quiz.id);
      throw new BadRequestError('Failed to save quiz questions. Aborted.');
    }

    return {
      ...quiz,
      questions: insertedQuestions || [],
    };
  }

  /**
   * 2. AI Question Generator for all sources (PDF, OCR, Lecture, AI topic, Teacher notes)
   */
  private static async generateQuestionsWithAI(
    params: NonNullable<CreateQuizDto['ai_generation']>,
    sourceType?: string
  ): Promise<RawQuizQuestion[]> {
    const {
      source_text = '',
      topic = '',
      course_name = '',
      question_count = 5,
      difficulty = 'medium',
      question_types = ['multiple_choice', 'true_false', 'short_answer'],
    } = params;

    const client = this.getGeminiClient();
    if (!client) {
      logger.warn('[QuizService] No Gemini API key configured. Generating educational fallback questions.');
      return this.getFallbackQuestions(params);
    }

    // SECURITY [H-06]: Sanitize user-supplied source_text to remove common prompt injection patterns
    // before embedding in the AI system prompt. Wrap in XML delimiters to signal untrusted content.
    const sanitizePromptContent = (text: string): string => {
      return text
        // Remove common injection trigger phrases
        .replace(/ignore\s+(previous|prior|above|all)\s+(instructions?|prompts?|rules?)/gi, '[FILTERED]')
        .replace(/disregard\s+(previous|prior|above|all)\s+(instructions?|prompts?|rules?)/gi, '[FILTERED]')
        .replace(/you\s+are\s+now\s+a/gi, '[FILTERED]')
        .replace(/act\s+as\s+(if\s+you\s+are|a)/gi, '[FILTERED]')
        .replace(/new\s+instructions?:/gi, '[FILTERED]')
        .replace(/system\s+prompt:/gi, '[FILTERED]')
        .replace(/\[\s*INST\s*\]/gi, '[FILTERED]')
        .replace(/<\s*system\s*>/gi, '[FILTERED]');
    };

    const rawContent = source_text.length > 8000 ? source_text.substring(0, 8000) : source_text;
    const contextContent = sanitizePromptContent(rawContent);

    const prompt = `You are ZankoAI's expert academic university quiz generator.
Generate exactly ${question_count} high-quality academic questions based on the following material:
Source Type: "${sourceType || 'ai_topic'}"
Topic: "${topic || 'General Academic Topic'}"
Course: "${course_name || 'Academic Course'}"
Difficulty: "${difficulty}"
Allowed Question Types: [${question_types.join(', ')}]

CRITICAL QUESTION RULES:
1. Question types MUST be chosen ONLY from: "multiple_choice", "true_false", "short_answer".
2. For "multiple_choice":
   - Provide 3 to 4 plausible, distinct options in an array.
   - "correct_answer" MUST be one of those exact options.
3. For "true_false":
   - "options" MUST be ["True", "False"].
   - "correct_answer" MUST be either "True" or "False".
4. For "short_answer":
   - "options" MUST be an empty array [].
   - Provide a definitive, clear concise "correct_answer".
5. MATH FORMATTING: NEVER use dollar signs ($ or $$) or LaTeX delimiters. Format all math expressions cleanly in plain text or Unicode (e.g. x², d/dx, ·, =).
6. Provide a concise, educational explanation for each question.
7. Respond ONLY with a valid JSON array of objects strictly matching this structure:
[
  {
    "question_text": "Question text here?",
    "question_type": "multiple_choice",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer": "Option B",
    "explanation": "Brief explanation why B is correct",
    "difficulty": "${difficulty}",
    "points": 1
  }
]

<SOURCE_MATERIAL>
${contextContent || topic}
</SOURCE_MATERIAL>`;


    try {
      const model = env.GEMINI_MODEL || 'gemini-2.5-flash';
      const response = await client.models.generateContent({
        model,
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        config: {
          temperature: 0.3,
          responseMimeType: 'application/json',
        },
      });

      const responseText = response.text || '[]';
      let cleanJson = responseText.replace(/```json/im, '').replace(/```/im, '').trim();
      const match = cleanJson.match(/\[\s*\{[\s\S]*\}\s*\]/);
      if (match) cleanJson = match[0];

      const parsed = JSON.parse(cleanJson);
      if (!Array.isArray(parsed) || parsed.length === 0) {
        throw new Error('AI returned an empty array of questions');
      }

      // Strictly validate every AI question; reject malformed questions!
      return validateQuestionList(parsed);
    } catch (err: any) {
      logger.warn('[QuizService] Gemini question generation failed or had malformed items:', err?.message);
      return this.getFallbackQuestions(params);
    }
  }

  /**
   * Deterministic fallback questions for offline / test environments
   */
  private static getFallbackQuestions(params: NonNullable<CreateQuizDto['ai_generation']>): RawQuizQuestion[] {
    const topic = params.topic || params.course_name || 'Academic Study';
    const diff = params.difficulty || 'medium';

    const fallback: RawQuizQuestion[] = [
      {
        question_text: `What is the core foundational principle of ${topic}?`,
        question_type: 'multiple_choice',
        options: [
          `Systematic analysis of ${topic}`,
          'Arbitrary subjective estimation',
          'Unverified random assumption',
          'Static unchangeable observation',
        ],
        correct_answer: `Systematic analysis of ${topic}`,
        explanation: `${topic} relies on structured academic methodology and evidence-based analysis.`,
        difficulty: diff,
        points: 1,
        order_index: 0,
      },
      {
        question_text: `In the study of ${topic}, empirical evidence is mandatory for verifying hypotheses.`,
        question_type: 'true_false',
        options: ['True', 'False'],
        correct_answer: 'True',
        explanation: 'Scientific inquiry requires verified experimental or observational evidence.',
        difficulty: diff,
        points: 1,
        order_index: 1,
      },
      {
        question_text: `State the primary goal or outcome achieved through understanding ${topic}.`,
        question_type: 'short_answer',
        options: [],
        correct_answer: 'Optimization and mastery',
        explanation: 'The primary goal is comprehensive understanding and practical problem-solving.',
        difficulty: diff,
        points: 1,
        order_index: 2,
      },
    ];

    return validateQuestionList(fallback);
  }

  /**
   * 3. Get Quiz by ID
   * IMPORTANT: Correct answers and explanations are NEVER exposed to students before submission!
   */
  static async getQuiz(quizId: string, callerId: string, callerRole: string): Promise<QuizRecord> {
    const { data: quiz, error: qErr } = await supabaseAdmin
      .from('quizzes')
      .select('*')
      .eq('id', quizId)
      .maybeSingle();

    if (qErr || !quiz) {
      throw new NotFoundError('Quiz not found');
    }

    // Check course authorization if course quiz
    if (quiz.course_id && callerRole === 'student') {
      const { data: membership } = await supabaseAdmin
        .from('course_members')
        .select('id')
        .eq('course_id', quiz.course_id)
        .eq('user_id', callerId)
        .maybeSingle();

      if (!membership && !quiz.is_published) {
        throw new ForbiddenError('You are not authorized to access this course quiz');
      }
    }

    // Check questions
    const { data: rawQuestions, error: qListErr } = await supabaseAdmin
      .from('quiz_questions')
      .select('*')
      .eq('quiz_id', quizId)
      .order('order_index', { ascending: true });

    if (qListErr) {
      throw new BadRequestError('Failed to load quiz questions');
    }

    // Check if caller has completed attempt
    const { data: completedAttempt } = await supabaseAdmin
      .from('quiz_attempts')
      .select('id')
      .eq('quiz_id', quizId)
      .eq('user_id', callerId)
      .eq('status', 'completed')
      .maybeSingle();

    const isTeacherOrAdmin = callerRole === 'admin' || callerRole === 'teacher' || quiz.creator_id === callerId;
    const canSeeAnswers = isTeacherOrAdmin || !!completedAttempt;

    const processedQuestions = canSeeAnswers
      ? (rawQuestions || [])
      : (rawQuestions || []).map((q) => {
          const sanitized: SanitizedQuizQuestion = {
            id: q.id,
            quiz_id: q.quiz_id,
            question_text: q.question_text,
            question_type: q.question_type,
            options: q.options || [],
            difficulty: q.difficulty,
            points: q.points,
            order_index: q.order_index,
          };
          return sanitized;
        });

    return {
      ...quiz,
      questions: processedQuestions,
    };
  }

  /**
   * 4. Start a Quiz Attempt
   * Creates or returns an active session and returns questions WITHOUT answers!
   */
  static async startAttempt(quizId: string, userId: string, userRole: string): Promise<StartQuizAttemptResult> {
    const quiz = await this.getQuiz(quizId, userId, userRole);

    // Look for active in-progress attempt
    const { data: activeAttempt } = await supabaseAdmin
      .from('quiz_attempts')
      .select('*')
      .eq('quiz_id', quizId)
      .eq('user_id', userId)
      .eq('status', 'in_progress')
      .order('started_at', { ascending: false })
      .maybeSingle();

    let attemptId: string;
    let startedAt: string;

    if (activeAttempt) {
      attemptId = activeAttempt.id;
      startedAt = activeAttempt.started_at;
    } else {
      const { data: newAttempt, error: attemptErr } = await supabaseAdmin
        .from('quiz_attempts')
        .insert({
          quiz_id: quizId,
          user_id: userId,
          status: 'in_progress',
          score: 0,
          total_points: 0,
          passed: false,
        })
        .select()
        .maybeSingle();

      if (attemptErr || !newAttempt) {
        logger.error('[QuizService] Failed to create quiz attempt:', attemptErr);
        throw new BadRequestError('Could not initialize quiz attempt session');
      }

      attemptId = newAttempt.id;
      startedAt = newAttempt.started_at;
    }

    // Fetch questions strictly sanitized (no correct_answer, no explanation)
    const { data: questions } = await supabaseAdmin
      .from('quiz_questions')
      .select('id, quiz_id, question_text, question_type, options, difficulty, points, order_index')
      .eq('quiz_id', quizId)
      .order('order_index', { ascending: true });

    return {
      attempt_id: attemptId,
      quiz_id: quizId,
      title: quiz.title,
      time_limit_minutes: quiz.time_limit_minutes,
      started_at: startedAt,
      question_count: (questions || []).length,
      questions: (questions || []) as SanitizedQuizQuestion[],
    };
  }

  /**
   * 5. Submit Quiz Attempt and Calculate Score Server-Side
   * Never trusts client score; evaluates true answers against DB questions!
   */
  static async submitAttempt(
    quizId: string,
    userId: string,
    dto: SubmitQuizAttemptDto
  ): Promise<QuizSubmissionResult> {
    // A. Verify attempt
    const { data: attempt, error: attemptErr } = await supabaseAdmin
      .from('quiz_attempts')
      .select('*')
      .eq('id', dto.attempt_id)
      .eq('user_id', userId)
      .maybeSingle();

    if (attemptErr || !attempt) {
      throw new NotFoundError('Quiz attempt session not found');
    }

    if (attempt.status === 'completed') {
      // If already submitted, return the existing evaluated result
      return this.getCompletedAttemptResult(dto.attempt_id, quizId, userId);
    }

    // B. Fetch quiz rules and all questions with correct answers
    const { data: quiz } = await supabaseAdmin
      .from('quizzes')
      .select('passing_score')
      .eq('id', quizId)
      .maybeSingle();

    const { data: questions } = await supabaseAdmin
      .from('quiz_questions')
      .select('*')
      .eq('quiz_id', quizId)
      .order('order_index', { ascending: true });

    if (!questions || questions.length === 0) {
      throw new BadRequestError('Quiz questions could not be loaded for evaluation');
    }

    const questionMap = new Map<string, any>();
    for (const q of questions) {
      questionMap.set(q.id, q);
    }

    // C. Evaluate Answers Strictly Server-Side
    let totalScore = 0;
    let maxPossiblePoints = 0;
    const evaluatedAnswers: EvaluatedAnswer[] = [];
    const answerRowsToInsert: any[] = [];

    // Map student submitted answers by question_id
    const studentAnswerMap = new Map<string, string>();
    for (const ans of dto.answers) {
      studentAnswerMap.set(ans.question_id, String(ans.selected_answer || '').trim());
    }

    for (const question of questions) {
      const maxPts = Number(question.points || 1);
      maxPossiblePoints += maxPts;

      const studentAns = studentAnswerMap.get(question.id) || '';
      const correctAns = String(question.correct_answer || '').trim();

      const isCorrect = this.checkAnswerCorrectness(
        question.question_type,
        studentAns,
        correctAns
      );

      const awardedPts = isCorrect ? maxPts : 0;
      totalScore += awardedPts;

      evaluatedAnswers.push({
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        selected_answer: studentAns,
        correct_answer: correctAns,
        is_correct: isCorrect,
        points_awarded: awardedPts,
        max_points: maxPts,
        explanation: question.explanation || undefined,
      });

      answerRowsToInsert.push({
        attempt_id: dto.attempt_id,
        question_id: question.id,
        selected_answer: studentAns,
        is_correct: isCorrect,
        points_awarded: awardedPts,
      });
    }

    const passingScore = Number(quiz?.passing_score ?? 50);
    const percentage = maxPossiblePoints > 0 ? (totalScore / maxPossiblePoints) * 100 : 0;
    const passed = percentage >= passingScore;
    const completedAt = new Date().toISOString();

    // D. Persist evaluated answers
    if (answerRowsToInsert.length > 0) {
      await supabaseAdmin.from('quiz_answers').upsert(answerRowsToInsert);
    }

    // E. Update attempt record
    await supabaseAdmin
      .from('quiz_attempts')
      .update({
        score: totalScore,
        total_points: maxPossiblePoints,
        passed,
        status: 'completed',
        completed_at: completedAt,
        time_spent_seconds: dto.time_spent_seconds || 0,
      })
      .eq('id', dto.attempt_id);

    return {
      attempt_id: dto.attempt_id,
      quiz_id: quizId,
      user_id: userId,
      score: totalScore,
      total_points: maxPossiblePoints,
      percentage: Number(percentage.toFixed(2)),
      passed,
      passing_score: passingScore,
      started_at: attempt.started_at,
      completed_at: completedAt,
      time_spent_seconds: dto.time_spent_seconds || 0,
      evaluated_answers: evaluatedAnswers,
    };
  }

  /**
   * Helper to fetch completed attempt results
   */
  private static async getCompletedAttemptResult(
    attemptId: string,
    quizId: string,
    userId: string
  ): Promise<QuizSubmissionResult> {
    const { data: attempt } = await supabaseAdmin
      .from('quiz_attempts')
      .select('*')
      .eq('id', attemptId)
      .maybeSingle();

    const { data: quiz } = await supabaseAdmin
      .from('quizzes')
      .select('passing_score')
      .eq('id', quizId)
      .maybeSingle();

    const { data: answers } = await supabaseAdmin
      .from('quiz_answers')
      .select('*, quiz_questions(question_text, question_type, correct_answer, explanation, points)')
      .eq('attempt_id', attemptId);

    const evaluatedAnswers: EvaluatedAnswer[] = (answers || []).map((a: any) => ({
      question_id: a.question_id,
      question_text: a.quiz_questions?.question_text || '',
      question_type: a.quiz_questions?.question_type || 'multiple_choice',
      selected_answer: a.selected_answer || '',
      correct_answer: a.quiz_questions?.correct_answer || '',
      is_correct: a.is_correct || false,
      points_awarded: Number(a.points_awarded || 0),
      max_points: Number(a.quiz_questions?.points || 1),
      explanation: a.quiz_questions?.explanation,
    }));

    const score = Number(attempt?.score || 0);
    const totalPoints = Number(attempt?.total_points || 0);
    const percentage = totalPoints > 0 ? (score / totalPoints) * 100 : 0;

    return {
      attempt_id: attemptId,
      quiz_id: quizId,
      user_id: userId,
      score,
      total_points: totalPoints,
      percentage: Number(percentage.toFixed(2)),
      passed: attempt?.passed || false,
      passing_score: Number(quiz?.passing_score || 50),
      started_at: attempt?.started_at,
      completed_at: attempt?.completed_at || new Date().toISOString(),
      time_spent_seconds: attempt?.time_spent_seconds || 0,
      evaluated_answers: evaluatedAnswers,
    };
  }

  /**
   * Accurate answer grading engine with normalization for different question types
   */
  static checkAnswerCorrectness(
    type: string,
    studentAnswer: string,
    correctAnswer: string
  ): boolean {
    const s = studentAnswer.trim().toLowerCase();
    const c = correctAnswer.trim().toLowerCase();

    if (!s || !c) return false;

    if (type === 'multiple_choice') {
      return s === c;
    }

    if (type === 'true_false') {
      const trueTokens = ['true', 't', 'ڕاست', 'صحیح', '1'];
      const falseTokens = ['false', 'f', 'هەڵە', 'خطأ', '0'];

      const sIsTrue = trueTokens.includes(s);
      const sIsFalse = falseTokens.includes(s);
      const cIsTrue = trueTokens.includes(c);
      const cIsFalse = falseTokens.includes(c);

      if (cIsTrue) return sIsTrue;
      if (cIsFalse) return sIsFalse;
      return s === c;
    }

    if (type === 'short_answer') {
      // Normalize punctuation and spacing for natural answers
      const normalize = (text: string) =>
        text
          .replace(/[.,/#!$%^&*;:{}=\-_`~()؟?]/g, '')
          .replace(/\s+/g, ' ')
          .trim();

      return normalize(s) === normalize(c);
    }

    return s === c;
  }

  // ==============================================================================
  // 6. Flashcards & Spaced Repetition (SM-2 Architecture)
  // ==============================================================================

  /**
   * Computes the SuperMemo-2 (SM-2) algorithm for optimal memory retention intervals
   */
  static calculateSM2(
    qualityRating: number, // 0 to 5
    currentBox: number = 1,
    currentEase: number = 2.50,
    currentInterval: number = 1,
    currentReps: number = 0
  ): SM2ReviewResult {
    const q = Math.max(0, Math.min(5, qualityRating));
    let nextInterval: number;
    let nextReps: number;
    let nextBox: number;

    if (q >= 3) {
      // Successful recall
      if (currentReps === 0) {
        nextInterval = 1;
      } else if (currentReps === 1) {
        nextInterval = 6;
      } else {
        nextInterval = Math.round(currentInterval * currentEase);
      }
      nextReps = currentReps + 1;
      nextBox = Math.min(5, currentBox + 1);
    } else {
      // Failed recall: reset repetitions and interval to 1 day
      nextInterval = 1;
      nextReps = 0;
      nextBox = 1;
    }

    // Update Ease Factor (EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
    let nextEase = currentEase + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    nextEase = Math.max(1.30, Math.min(2.50, Number(nextEase.toFixed(2))));

    const nextReviewDate = new Date(Date.now() + nextInterval * 24 * 60 * 60 * 1000).toISOString();

    return {
      box: nextBox,
      ease_factor: nextEase,
      interval_days: nextInterval,
      repetitions: nextReps,
      next_review_at: nextReviewDate,
    };
  }

  /**
   * Record review for a flashcard and update its spaced-repetition progress
   */
  static async reviewFlashcard(
    flashcardId: string,
    userId: string,
    qualityRating: number
  ): Promise<SM2ReviewResult> {
    const { data: card } = await supabaseAdmin
      .from('flashcards')
      .select('id')
      .eq('id', flashcardId)
      .maybeSingle();

    if (!card) {
      throw new NotFoundError('Flashcard not found');
    }

    // Get current progress or default
    const { data: progress } = await supabaseAdmin
      .from('flashcard_progress')
      .select('*')
      .eq('flashcard_id', flashcardId)
      .eq('user_id', userId)
      .maybeSingle();

    const currentBox = progress?.box ?? 1;
    const currentEase = Number(progress?.ease_factor ?? 2.50);
    const currentInterval = progress?.interval_days ?? 1;
    const currentReps = progress?.repetitions ?? 0;

    const sm2 = this.calculateSM2(
      qualityRating,
      currentBox,
      currentEase,
      currentInterval,
      currentReps
    );

    const now = new Date().toISOString();

    await supabaseAdmin.from('flashcard_progress').upsert({
      flashcard_id: flashcardId,
      user_id: userId,
      box: sm2.box,
      ease_factor: sm2.ease_factor,
      interval_days: sm2.interval_days,
      repetitions: sm2.repetitions,
      next_review_at: sm2.next_review_at,
      last_reviewed_at: now,
      updated_at: now,
    });

    return sm2;
  }

  /**
   * Fetch flashcards that are due for spaced review
   */
  static async getDueFlashcards(userId: string, courseId?: string) {
    const now = new Date().toISOString();

    let query = supabaseAdmin
      .from('flashcards')
      .select('*, flashcard_progress!inner(*)')
      .eq('flashcard_progress.user_id', userId)
      .lte('flashcard_progress.next_review_at', now);

    if (courseId) {
      query = query.eq('course_id', courseId);
    }

    const { data, error } = await query;
    if (error) {
      logger.error('[QuizService] Failed to query due flashcards:', error);
      throw new BadRequestError('Could not fetch due flashcards');
    }

    return data || [];
  }
}
