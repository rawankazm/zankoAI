import { LearningRepository } from '../repositories/learning.repository.js';
import { ParsedQuery, QueryHelper } from '../utils/queryBuilder.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../utils/apiError.js';
import { supabaseAdmin } from '../config/supabase.js';

export class LearningService {
  // ─── Lectures ───
  static async getCourseLectures(courseId: string, query: ParsedQuery) {
    const { items, total } = await LearningRepository.listLectures(courseId, query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getLecture(id: string) {
    const lecture = await LearningRepository.getLectureById(id);
    if (!lecture) throw new NotFoundError('Lecture not found');
    return lecture;
  }

  static async createLecture(data: any, callerId?: string, callerRole?: string) {
    if (callerRole && callerRole !== 'admin' && callerId) {
      const { data: course } = await supabaseAdmin
        .from('courses')
        .select('instructor_id')
        .eq('id', data.course_id)
        .maybeSingle();

      if (!course) throw new NotFoundError('Course not found');
      if (course.instructor_id !== callerId) {
        throw new ForbiddenError('You can only create lectures for courses you instruct');
      }
    }
    return LearningRepository.createLecture(data);
  }

  static async updateLecture(id: string, data: any, callerId?: string, callerRole?: string) {
    const lecture = await LearningRepository.getLectureById(id);
    if (!lecture) throw new NotFoundError('Lecture not found');

    if (callerRole && callerRole !== 'admin' && callerId) {
      const { data: course } = await supabaseAdmin
        .from('courses')
        .select('instructor_id')
        .eq('id', lecture.course_id)
        .maybeSingle();

      if (!course || course.instructor_id !== callerId) {
        throw new ForbiddenError('You can only update lectures for courses you instruct');
      }
    }

    const updated = await LearningRepository.updateLecture(id, data);
    return updated;
  }

  static async deleteLecture(id: string, callerId?: string, callerRole?: string) {
    const lecture = await LearningRepository.getLectureById(id);
    if (!lecture) throw new NotFoundError('Lecture not found');

    if (callerRole && callerRole !== 'admin' && callerId) {
      const { data: course } = await supabaseAdmin
        .from('courses')
        .select('instructor_id')
        .eq('id', lecture.course_id)
        .maybeSingle();

      if (!course || course.instructor_id !== callerId) {
        throw new ForbiddenError('You can only delete lectures for courses you instruct');
      }
    }

    return LearningRepository.deleteLecture(id);
  }

  // ─── Assignments ───
  static async getCourseAssignments(courseId: string, query: ParsedQuery) {
    const { items, total } = await LearningRepository.listAssignments(courseId, query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getAssignment(id: string) {
    const assignment = await LearningRepository.getAssignmentById(id);
    if (!assignment) throw new NotFoundError('Assignment not found');
    return assignment;
  }

  static async createAssignment(callerId: string, callerRole: string, data: any) {
    if (callerRole !== 'admin') {
      const { data: course } = await supabaseAdmin
        .from('courses')
        .select('instructor_id')
        .eq('id', data.course_id)
        .maybeSingle();

      if (!course) throw new NotFoundError('Course not found');
      if (course.instructor_id !== callerId) {
        throw new ForbiddenError('You can only create assignments for courses you instruct');
      }
    }

    return LearningRepository.createAssignment({
      ...data,
      creator_id: callerId,
    });
  }

  static async updateAssignment(id: string, data: any, callerId?: string, callerRole?: string) {
    const assignment = await LearningRepository.getAssignmentById(id);
    if (!assignment) throw new NotFoundError('Assignment not found');

    if (callerRole && callerRole !== 'admin' && callerId) {
      if (assignment.creator_id !== callerId) {
        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('instructor_id')
          .eq('id', assignment.course_id)
          .maybeSingle();

        if (!course || course.instructor_id !== callerId) {
          throw new ForbiddenError('You can only update assignments for courses you instruct');
        }
      }
    }

    const updated = await LearningRepository.updateAssignment(id, data);
    return updated;
  }

  static async deleteAssignment(id: string, callerId?: string, callerRole?: string) {
    const assignment = await LearningRepository.getAssignmentById(id);
    if (!assignment) throw new NotFoundError('Assignment not found');

    if (callerRole && callerRole !== 'admin' && callerId) {
      if (assignment.creator_id !== callerId) {
        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('instructor_id')
          .eq('id', assignment.course_id)
          .maybeSingle();

        if (!course || course.instructor_id !== callerId) {
          throw new ForbiddenError('You can only delete assignments for courses you instruct');
        }
      }
    }

    return LearningRepository.deleteAssignment(id);
  }

  // ─── Submissions ───
  static async getAssignmentSubmissions(assignmentId: string, callerId: string, callerRole: string) {
    const assignment = await LearningRepository.getAssignmentById(assignmentId);
    if (!assignment) throw new NotFoundError('Assignment not found');

    if (callerRole === 'admin') {
      return LearningRepository.getSubmissions(assignmentId);
    }

    if (callerRole === 'teacher') {
      // Check if teacher created the assignment
      if (assignment.creator_id === callerId) {
        return LearningRepository.getSubmissions(assignmentId);
      }
      // Check if teacher is assigned to this course
      const { data: course } = await supabaseAdmin
        .from('courses')
        .select('instructor_id')
        .eq('id', assignment.course_id)
        .maybeSingle();

      if (course && course.instructor_id === callerId) {
        return LearningRepository.getSubmissions(assignmentId);
      }

      throw new ForbiddenError('You can only view submissions for courses you instruct');
    }

    // Student only sees their own submission
    return LearningRepository.getSubmissions(assignmentId, callerId);
  }

  static async submitAssignment(assignmentId: string, studentId: string, data: any) {
    const assignment = await LearningRepository.getAssignmentById(assignmentId);
    if (!assignment) throw new NotFoundError('Assignment not found');

    return LearningRepository.submitAssignment(assignmentId, studentId, data);
  }

  static async gradeSubmission(submissionId: string, graderId: string, graderRole: string, data: any) {
    if (graderRole !== 'admin') {
      const { data: submission } = await supabaseAdmin
        .from('assignment_submissions')
        .select('assignment_id, assignments(course_id, creator_id)')
        .eq('id', submissionId)
        .maybeSingle();

      if (!submission) throw new NotFoundError('Submission not found');

      const assignment = (submission as any).assignments;
      if (assignment) {
        if (assignment.creator_id !== graderId) {
          const { data: course } = await supabaseAdmin
            .from('courses')
            .select('instructor_id')
            .eq('id', assignment.course_id)
            .maybeSingle();

          if (!course || course.instructor_id !== graderId) {
            throw new ForbiddenError('You can only grade submissions for courses you instruct');
          }
        }
      }
    }

    return LearningRepository.gradeSubmission(submissionId, graderId, data);
  }

  // ─── Quizzes ───
  static async getCourseQuizzes(courseId: string, query: ParsedQuery) {
    const { items, total } = await LearningRepository.listQuizzes(courseId, query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getQuiz(id: string, callerRole: string) {
    const sanitize = callerRole === 'student';
    const quiz = await LearningRepository.getQuizWithQuestions(id, sanitize);
    if (!quiz) throw new NotFoundError('Quiz not found');
    return quiz;
  }

  static async createQuiz(callerId: string, data: any) {
    return LearningRepository.createQuiz({
      ...data,
      creator_id: callerId,
    });
  }

  static async updateQuiz(id: string, data: any, callerId?: string, callerRole?: string) {
    const { data: quiz } = await supabaseAdmin
      .from('quizzes')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (!quiz) throw new NotFoundError('Quiz not found');

    if (callerRole && callerRole !== 'admin' && callerId) {
      if (quiz.creator_id !== callerId) {
        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('instructor_id')
          .eq('id', quiz.course_id)
          .maybeSingle();

        if (!course || course.instructor_id !== callerId) {
          throw new ForbiddenError('You can only modify quizzes for courses you instruct');
        }
      }
    }

    const { data: updated, error } = await supabaseAdmin
      .from('quizzes')
      .update({ ...data, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error) throw error;
    return updated;
  }

  static async addQuestion(data: any, callerId?: string, callerRole?: string) {
    if (callerRole && callerRole !== 'admin' && callerId) {
      const { data: quiz } = await supabaseAdmin
        .from('quizzes')
        .select('creator_id, course_id')
        .eq('id', data.quiz_id)
        .maybeSingle();

      if (!quiz) throw new NotFoundError('Quiz not found');

      if (quiz.creator_id !== callerId) {
        const { data: course } = await supabaseAdmin
          .from('courses')
          .select('instructor_id')
          .eq('id', quiz.course_id)
          .maybeSingle();

        if (!course || course.instructor_id !== callerId) {
          throw new ForbiddenError('You can only add questions to quizzes for courses you instruct');
        }
      }
    }

    return LearningRepository.addQuizQuestion(data);
  }

  static async submitQuizAttempt(quizId: string, userId: string, answers: { question_id: string; selected_answer: string }[]) {
    // Fetch quiz with full question details including correct answers
    const quiz = await LearningRepository.getQuizWithQuestions(quizId, false);
    if (!quiz) throw new NotFoundError('Quiz not found');

    const questionMap = new Map<string, any>();
    for (const q of quiz.questions) {
      questionMap.set(q.id, q);
    }

    let earnedScore = 0;
    let totalPoints = 0;

    for (const q of quiz.questions) {
      totalPoints += Number(q.points || 1);
    }

    const answerRecords: any[] = [];

    for (const ans of answers) {
      const question = questionMap.get(ans.question_id);
      if (question) {
        const isCorrect = String(question.correct_answer).trim().toLowerCase() === String(ans.selected_answer).trim().toLowerCase();
        const pts = isCorrect ? Number(question.points || 1) : 0;
        earnedScore += pts;
        answerRecords.push({
          question_id: ans.question_id,
          selected_answer: ans.selected_answer,
          is_correct: isCorrect,
          points_awarded: pts,
        });
      }
    }

    const passed = earnedScore >= Number(quiz.passing_score || 50);

    const attempt = await LearningRepository.recordQuizAttempt(
      quizId,
      userId,
      earnedScore,
      totalPoints,
      passed
    );

    return {
      attemptId: attempt?.id,
      score: earnedScore,
      totalPoints,
      passed,
      answersEvaluated: answerRecords.length,
    };
  }

  // ─── Flashcards ───
  static async getFlashcards(userId: string, courseId?: string, query?: ParsedQuery) {
    const { items, total } = await LearningRepository.listFlashcards(userId, courseId, query);
    if (query) {
      return QueryHelper.formatResult(items, total, query.page, query.limit);
    }
    return { items, total };
  }

  static async createFlashcard(callerId: string, data: any) {
    return LearningRepository.createFlashcard({
      ...data,
      creator_id: callerId,
    });
  }

  static async updateFlashcard(id: string, callerId: string, callerRole: string, data: any) {
    const { data: existing } = await supabaseAdmin.from('flashcards').select('creator_id').eq('id', id).maybeSingle();
    if (!existing) throw new NotFoundError('Flashcard not found');

    if (callerRole !== 'admin' && existing.creator_id !== callerId) {
      throw new ForbiddenError('You can only modify your own flashcards');
    }

    return LearningRepository.updateFlashcard(id, data);
  }

  static async deleteFlashcard(id: string, callerId: string, callerRole: string) {
    const { data: existing } = await supabaseAdmin.from('flashcards').select('creator_id').eq('id', id).maybeSingle();
    if (!existing) throw new NotFoundError('Flashcard not found');

    if (callerRole !== 'admin' && existing.creator_id !== callerId) {
      throw new ForbiddenError('You can only delete your own flashcards');
    }

    return LearningRepository.deleteFlashcard(id);
  }
}
