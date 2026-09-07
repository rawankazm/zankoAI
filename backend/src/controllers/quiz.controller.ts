// ==============================================================================
// ZankoAI Quiz & Flashcard Express Controller
// ==============================================================================

import { Request, Response } from 'express';
import { QuizService } from '../services/quiz.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';

export class QuizController {
  /**
   * POST /api/quizzes
   * Create manual or AI-generated quiz
   */
  static async createQuiz(req: Request, res: Response): Promise<Response> {
    const callerId = req.user!.id;
    const callerRole = req.profile?.role || 'student';

    const quiz = await QuizService.createQuiz(callerId, callerRole, req.body);
    return ResponseFormatter.created(res, quiz, 'Quiz created successfully');
  }

  /**
   * GET /api/quizzes/:id
   * Fetch quiz details with anti-cheating answer sanitization
   */
  static async getQuiz(req: Request, res: Response): Promise<Response> {
    const callerId = req.user!.id;
    const callerRole = req.profile?.role || 'student';

    const quiz = await QuizService.getQuiz(req.params.id, callerId, callerRole);
    return ResponseFormatter.success(res, quiz);
  }

  /**
   * POST /api/quizzes/:id/start
   * Start or resume quiz attempt session without correct answers
   */
  static async startAttempt(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const userRole = req.profile?.role || 'student';

    const result = await QuizService.startAttempt(req.params.id, userId, userRole);
    return ResponseFormatter.created(res, result, 'Quiz session started');
  }

  /**
   * POST /api/quizzes/:id/submit
   * Submit quiz answers with server-enforced evaluation & score calculation
   */
  static async submitAttempt(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;

    const result = await QuizService.submitAttempt(req.params.id, userId, req.body);
    return ResponseFormatter.success(res, result, 'Quiz submitted and evaluated successfully');
  }

  /**
   * POST /api/flashcards/:id/review
   * Record SM-2 spaced repetition review rating (0-5)
   */
  static async reviewFlashcard(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const rating = Number(req.body.rating);

    const sm2Result = await QuizService.reviewFlashcard(req.params.id, userId, rating);
    return ResponseFormatter.success(res, sm2Result, 'Flashcard review recorded');
  }

  /**
   * GET /api/flashcards/due
   * Retrieve flashcards due for review based on spaced intervals
   */
  static async getDueFlashcards(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const courseId = req.query.course_id as string | undefined;

    const dueCards = await QuizService.getDueFlashcards(userId, courseId);
    return ResponseFormatter.success(res, dueCards);
  }
}
