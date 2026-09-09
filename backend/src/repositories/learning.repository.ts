import { supabaseAdmin } from '../config/supabase.js';
import { ParsedQuery } from '../utils/queryBuilder.js';

export class LearningRepository {
  // ─── Lectures ───
  static async listLectures(courseId: string, query: ParsedQuery) {
    let req = supabaseAdmin
      .from('lectures')
      .select('*', { count: 'exact' })
      .eq('course_id', courseId);

    if (query.search) {
      req = req.ilike('title', `%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getLectureById(id: string) {
    const { data, error } = await supabaseAdmin.from('lectures').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createLecture(data: any) {
    const { data: res, error } = await supabaseAdmin.from('lectures').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateLecture(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('lectures').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteLecture(id: string) {
    const { error } = await supabaseAdmin.from('lectures').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Assignments ───
  static async listAssignments(courseId: string, query: ParsedQuery) {
    let req = supabaseAdmin
      .from('assignments')
      .select('*', { count: 'exact' })
      .eq('course_id', courseId);

    if (query.search) {
      req = req.ilike('title', `%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getAssignmentById(id: string) {
    const { data, error } = await supabaseAdmin.from('assignments').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createAssignment(data: any) {
    const { data: res, error } = await supabaseAdmin.from('assignments').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateAssignment(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('assignments').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteAssignment(id: string) {
    const { error } = await supabaseAdmin.from('assignments').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Assignment Submissions ───
  static async getSubmissions(assignmentId: string, studentId?: string) {
    let req = supabaseAdmin
      .from('assignment_submissions')
      .select('*, profiles:student_id(id, full_name, email, avatar_url)')
      .eq('assignment_id', assignmentId);

    if (studentId) {
      req = req.eq('student_id', studentId);
    }

    const { data, error } = await req.order('submitted_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  static async submitAssignment(assignmentId: string, studentId: string, data: any) {
    const { data: res, error } = await supabaseAdmin
      .from('assignment_submissions')
      .upsert(
        {
          assignment_id: assignmentId,
          student_id: studentId,
          ...data,
          submitted_at: new Date().toISOString(),
          status: 'submitted',
        },
        { onConflict: 'assignment_id,student_id' }
      )
      .select()
      .maybeSingle();

    if (error) throw error;
    return res;
  }

  static async gradeSubmission(submissionId: string, graderId: string, data: any) {
    const { data: res, error } = await supabaseAdmin
      .from('assignment_submissions')
      .update({
        ...data,
        graded_by: graderId,
        graded_at: new Date().toISOString(),
      })
      .eq('id', submissionId)
      .select()
      .maybeSingle();

    if (error) throw error;
    return res;
  }

  // ─── Quizzes & Questions ───
  static async listQuizzes(courseId: string, query: ParsedQuery) {
    let req = supabaseAdmin
      .from('quizzes')
      .select('*, quiz_questions(count)', { count: 'exact' })
      .eq('course_id', courseId);

    if (query.search) {
      req = req.ilike('title', `%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getQuizWithQuestions(id: string, sanitizeAnswers = true) {
    const [quizRes, questionsRes] = await Promise.all([
      supabaseAdmin.from('quizzes').select('*').eq('id', id).maybeSingle(),
      supabaseAdmin
        .from('quiz_questions')
        .select('*')
        .eq('quiz_id', id)
        .order('order_index', { ascending: true }),
    ]);

    if (quizRes.error || !quizRes.data) return null;
    if (questionsRes.error) throw questionsRes.error;

    const quiz = quizRes.data;
    const questions = questionsRes.data || [];

    // Sanitize correct_answer from students during active taking
    const cleanQuestions = sanitizeAnswers
      ? questions.map(({ correct_answer, explanation, ...rest }: any) => rest)
      : questions;

    return { ...quiz, questions: cleanQuestions };
  }

  static async createQuiz(data: any) {
    const { data: res, error } = await supabaseAdmin.from('quizzes').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async addQuizQuestion(data: any) {
    const { data: res, error } = await supabaseAdmin.from('quiz_questions').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async recordQuizAttempt(quizId: string, userId: string, score: number, totalPoints: number, passed: boolean) {
    const { data: res, error } = await supabaseAdmin
      .from('quiz_attempts')
      .insert([
        {
          quiz_id: quizId,
          user_id: userId,
          score,
          total_points: totalPoints,
          passed,
          status: 'completed',
          completed_at: new Date().toISOString(),
        },
      ])
      .select()
      .maybeSingle();

    if (error) throw error;
    return res;
  }

  // ─── Flashcards ───
  static async listFlashcards(userId: string, courseId?: string, query?: ParsedQuery) {
    let req = supabaseAdmin.from('flashcards').select('*', { count: 'exact' });

    if (courseId) {
      req = req.eq('course_id', courseId);
    } else {
      req = req.or(`creator_id.eq.${userId},is_public.eq.true`);
    }

    if (query?.search) {
      req = req.or(`front_text.ilike.%${query.search}%,back_text.ilike.%${query.search}%`);
    }

    if (query) {
      req = req
        .order(query.sortField, { ascending: query.sortAsc })
        .range(query.offset, query.offset + query.limit - 1);
    }

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async createFlashcard(data: any) {
    const { data: res, error } = await supabaseAdmin.from('flashcards').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateFlashcard(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('flashcards').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteFlashcard(id: string) {
    const { error } = await supabaseAdmin.from('flashcards').delete().eq('id', id);
    if (error) throw error;
    return true;
  }
}
