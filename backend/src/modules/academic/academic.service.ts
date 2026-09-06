import { supabaseAdmin } from '../../config/supabase.js';

export class AcademicService {
  async getUniversities() {
    const { data, error } = await supabaseAdmin
      .from('universities')
      .select('*, faculties(*, departments(*))')
      .order('name_ku', { ascending: true });

    if (error) throw error;
    return data;
  }

  async getCoursesByDepartment(departmentId: string, stage?: number) {
    let query = supabaseAdmin
      .from('courses')
      .select('*, lectures(*)')
      .eq('department_id', departmentId);

    if (stage) {
      query = query.eq('stage', stage);
    }

    const { data, error } = await query.order('created_at', { ascending: true });
    if (error) throw error;
    return data;
  }

  async createLecture(
    courseId: string,
    uploadedBy: string,
    title: string,
    fileUrl: string,
    fileType: string,
    fileSizeBytes: number
  ) {
    const { data, error } = await supabaseAdmin
      .from('lectures')
      .insert({
        course_id: courseId,
        uploaded_by: uploadedBy,
        title,
        file_url: fileUrl,
        file_type: fileType,
        file_size_bytes: fileSizeBytes,
        is_processed: false,
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }
}

export const academicService = new AcademicService();
