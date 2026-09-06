import { supabaseAdmin } from '../config/supabase.js';

export interface CourseRecord {
  id: string;
  department_id: string;
  instructor_id?: string | null;
  title: string;
  title_ku?: string | null;
  code: string;
  description?: string | null;
  stage: number;
  semester: number;
  credits: number;
  is_published: boolean;
  created_at: string;
}

export class CourseRepository {
  static async findByTeacher(teacherId: string): Promise<CourseRecord[]> {
    const { data, error } = await supabaseAdmin
      .from('courses')
      .select('*')
      .eq('instructor_id', teacherId)
      .order('created_at', { ascending: false });

    if (error || !data) return [];
    return data as CourseRecord[];
  }

  static async createCourse(course: Partial<CourseRecord>): Promise<CourseRecord | null> {
    const { data, error } = await supabaseAdmin
      .from('courses')
      .insert([course])
      .select()
      .maybeSingle();

    if (error || !data) return null;
    return data as CourseRecord;
  }

  static async getCourseStudents(courseId: string): Promise<any[]> {
    const { data, error } = await supabaseAdmin
      .from('course_members')
      .select(`
        user_id,
        role,
        enrolled_at,
        profiles (
          id,
          full_name,
          email,
          avatar_url,
          score
        )
      `)
      .eq('course_id', courseId);

    if (error || !data) return [];
    return data;
  }
}
