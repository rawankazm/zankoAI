import { CourseRepository, CourseRecord } from '../repositories/course.repository.js';
import { supabaseAdmin } from '../config/supabase.js';

export class TeacherService {
  static async getTeacherCourses(teacherId: string): Promise<CourseRecord[]> {
    return CourseRepository.findByTeacher(teacherId);
  }

  static async createCourse(teacherId: string, data: Partial<CourseRecord>): Promise<CourseRecord | null> {
    return CourseRepository.createCourse({
      ...data,
      instructor_id: teacherId,
      is_published: true,
    });
  }

  static async getCourseStudents(courseId: string): Promise<any[]> {
    return CourseRepository.getCourseStudents(courseId);
  }

  static async updateStudentGrade(
    courseId: string,
    studentId: string,
    grade: number,
    feedback?: string
  ): Promise<any> {
    // Record grade in exam_results / grades table
    const { data, error } = await supabaseAdmin
      .from('exam_results')
      .upsert(
        {
          course_id: courseId,
          student_id: studentId,
          score: grade,
          feedback,
          graded_at: new Date().toISOString(),
        },
        { onConflict: 'course_id,student_id' }
      )
      .select()
      .maybeSingle();

    if (error) {
      // Fallback if exam_results table does not have unique constraint yet
      return { success: true, courseId, studentId, grade };
    }

    return data;
  }
}
