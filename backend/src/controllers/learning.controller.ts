import { Request, Response } from 'express';
import { LearningService } from '../services/learning.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { QueryHelper } from '../utils/queryBuilder.js';

export class LearningController {
  // ─── Lectures ───
  static async listLectures(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId || (req.query.course_id as string);
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['order_index', 'title', 'created_at'],
      defaultSortField: 'order_index',
      defaultSortAsc: true,
    });
    const result = await LearningService.getCourseLectures(courseId, query);
    return ResponseFormatter.success(res, result);
  }

  static async getLecture(req: Request, res: Response): Promise<Response> {
    const lecture = await LearningService.getLecture(req.params.id);
    return ResponseFormatter.success(res, lecture);
  }

  static async createLecture(req: Request, res: Response): Promise<Response> {
    const lecture = await LearningService.createLecture(
      req.body,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.created(res, lecture, 'Lecture created successfully');
  }

  static async updateLecture(req: Request, res: Response): Promise<Response> {
    const lecture = await LearningService.updateLecture(
      req.params.id,
      req.body,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.success(res, lecture, 'Lecture updated successfully');
  }

  static async deleteLecture(req: Request, res: Response): Promise<Response> {
    await LearningService.deleteLecture(
      req.params.id,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.success(res, null, 'Lecture deleted successfully');
  }

  // ─── Assignments ───
  static async listAssignments(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId || (req.query.course_id as string);
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['due_date', 'title', 'created_at'],
      defaultSortField: 'due_date',
      defaultSortAsc: true,
    });
    const result = await LearningService.getCourseAssignments(courseId, query);
    return ResponseFormatter.success(res, result);
  }

  static async getAssignment(req: Request, res: Response): Promise<Response> {
    const assignment = await LearningService.getAssignment(req.params.id);
    return ResponseFormatter.success(res, assignment);
  }

  static async createAssignment(req: Request, res: Response): Promise<Response> {
    const assignment = await LearningService.createAssignment(
      req.user!.id,
      req.profile?.role || 'teacher',
      req.body
    );
    return ResponseFormatter.created(res, assignment, 'Assignment created successfully');
  }

  static async updateAssignment(req: Request, res: Response): Promise<Response> {
    const assignment = await LearningService.updateAssignment(
      req.params.id,
      req.body,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.success(res, assignment, 'Assignment updated successfully');
  }

  static async deleteAssignment(req: Request, res: Response): Promise<Response> {
    await LearningService.deleteAssignment(
      req.params.id,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.success(res, null, 'Assignment deleted successfully');
  }

  // ─── Submissions ───
  static async getSubmissions(req: Request, res: Response): Promise<Response> {
    const submissions = await LearningService.getAssignmentSubmissions(
      req.params.assignmentId,
      req.user!.id,
      req.profile!.role
    );
    return ResponseFormatter.success(res, submissions);
  }

  static async submitAssignment(req: Request, res: Response): Promise<Response> {
    const submission = await LearningService.submitAssignment(
      req.params.assignmentId,
      req.user!.id,
      req.body
    );
    return ResponseFormatter.created(res, submission, 'Assignment submitted successfully');
  }

  static async gradeSubmission(req: Request, res: Response): Promise<Response> {
    const graded = await LearningService.gradeSubmission(
      req.params.submissionId,
      req.user!.id,
      req.profile!.role,
      req.body
    );
    return ResponseFormatter.success(res, graded, 'Submission graded successfully');
  }

  // ─── Quizzes ───
  static async listQuizzes(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId || (req.query.course_id as string);
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['title', 'created_at'],
      defaultSortField: 'created_at',
      defaultSortAsc: false,
    });
    const result = await LearningService.getCourseQuizzes(courseId, query);
    return ResponseFormatter.success(res, result);
  }

  static async getQuiz(req: Request, res: Response): Promise<Response> {
    const quiz = await LearningService.getQuiz(req.params.id, req.profile!.role);
    return ResponseFormatter.success(res, quiz);
  }

  static async createQuiz(req: Request, res: Response): Promise<Response> {
    const quiz = await LearningService.createQuiz(req.user!.id, req.body);
    return ResponseFormatter.created(res, quiz, 'Quiz created successfully');
  }

  static async updateQuiz(req: Request, res: Response): Promise<Response> {
    const quiz = await LearningService.updateQuiz(
      req.params.id,
      req.body,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.success(res, quiz, 'Quiz updated successfully');
  }

  static async addQuestion(req: Request, res: Response): Promise<Response> {
    const question = await LearningService.addQuestion(
      req.body,
      req.user!.id,
      req.profile?.role || 'teacher'
    );
    return ResponseFormatter.created(res, question, 'Question added successfully');
  }

  static async submitQuizAttempt(req: Request, res: Response): Promise<Response> {
    const result = await LearningService.submitQuizAttempt(
      req.params.id,
      req.user!.id,
      req.body.answers
    );
    return ResponseFormatter.success(res, result, 'Quiz attempt submitted and evaluated');
  }

  // ─── Flashcards ───
  static async listFlashcards(req: Request, res: Response): Promise<Response> {
    const courseId = req.query.course_id as string;
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['deck_name', 'created_at'],
      defaultSortField: 'created_at',
      defaultSortAsc: false,
    });
    const result = await LearningService.getFlashcards(req.user!.id, courseId, query);
    return ResponseFormatter.success(res, result);
  }

  static async createFlashcard(req: Request, res: Response): Promise<Response> {
    const card = await LearningService.createFlashcard(req.user!.id, req.body);
    return ResponseFormatter.created(res, card, 'Flashcard created successfully');
  }

  static async updateFlashcard(req: Request, res: Response): Promise<Response> {
    const card = await LearningService.updateFlashcard(
      req.params.id,
      req.user!.id,
      req.profile!.role,
      req.body
    );
    return ResponseFormatter.success(res, card, 'Flashcard updated successfully');
  }

  static async deleteFlashcard(req: Request, res: Response): Promise<Response> {
    await LearningService.deleteFlashcard(req.params.id, req.user!.id, req.profile!.role);
    return ResponseFormatter.success(res, null, 'Flashcard deleted successfully');
  }
}
