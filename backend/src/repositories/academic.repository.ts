import { supabaseAdmin } from '../config/supabase.js';
import { ParsedQuery } from '../utils/queryBuilder.js';

export class AcademicRepository {
  // ─── Universities ───
  static async listUniversities(query: ParsedQuery) {
    let req = supabaseAdmin.from('universities').select('*', { count: 'exact' });

    if (query.search) {
      req = req.or(`name.ilike.%${query.search}%,city.ilike.%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getUniversityById(id: string) {
    const { data, error } = await supabaseAdmin.from('universities').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createUniversity(data: any) {
    const { data: res, error } = await supabaseAdmin.from('universities').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateUniversity(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('universities').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteUniversity(id: string) {
    const { error } = await supabaseAdmin.from('universities').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Faculties ───
  static async listFaculties(query: ParsedQuery) {
    let req = supabaseAdmin.from('faculties').select('*, universities(name)', { count: 'exact' });

    if (query.filters.university_id) {
      req = req.eq('university_id', query.filters.university_id);
    }
    if (query.search) {
      req = req.ilike('name', `%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getFacultyById(id: string) {
    const { data, error } = await supabaseAdmin.from('faculties').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createFaculty(data: any) {
    const { data: res, error } = await supabaseAdmin.from('faculties').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateFaculty(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('faculties').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteFaculty(id: string) {
    const { error } = await supabaseAdmin.from('faculties').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Departments ───
  static async listDepartments(query: ParsedQuery) {
    let req = supabaseAdmin.from('departments').select('*, faculties(name, university_id)', { count: 'exact' });

    if (query.filters.faculty_id) {
      req = req.eq('faculty_id', query.filters.faculty_id);
    }
    if (query.search) {
      req = req.ilike('name', `%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getDepartmentById(id: string) {
    const { data, error } = await supabaseAdmin.from('departments').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createDepartment(data: any) {
    const { data: res, error } = await supabaseAdmin.from('departments').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateDepartment(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('departments').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteDepartment(id: string) {
    const { error } = await supabaseAdmin.from('departments').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Courses ───
  static async listCourses(query: ParsedQuery) {
    let req = supabaseAdmin.from('courses').select('*, departments(name), profiles:instructor_id(id, full_name)', { count: 'exact' });

    if (query.filters.department_id) {
      req = req.eq('department_id', query.filters.department_id);
    }
    if (query.filters.instructor_id) {
      req = req.eq('instructor_id', query.filters.instructor_id);
    }
    if (query.filters.stage) {
      req = req.eq('stage', query.filters.stage);
    }
    if (query.filters.semester) {
      req = req.eq('semester', query.filters.semester);
    }
    if (query.search) {
      req = req.or(`title.ilike.%${query.search}%,code.ilike.%${query.search}%`);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }

  static async getCourseById(id: string) {
    const { data, error } = await supabaseAdmin
      .from('courses')
      .select('*, departments(name), instructor:instructor_id(id, full_name, email)')
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  static async createCourse(data: any) {
    const { data: res, error } = await supabaseAdmin.from('courses').insert([data]).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async updateCourse(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin.from('courses').update(data).eq('id', id).select().maybeSingle();
    if (error) throw error;
    return res;
  }

  static async deleteCourse(id: string) {
    const { error } = await supabaseAdmin.from('courses').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Course Members / Enrollment ───
  static async enrollMember(courseId: string, userId: string, role = 'student') {
    const { data, error } = await supabaseAdmin
      .from('course_members')
      .upsert(
        {
          course_id: courseId,
          user_id: userId,
          role,
          is_active: true,
          joined_at: new Date().toISOString(),
        },
        { onConflict: 'course_id,user_id' }
      )
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  static async unenrollMember(courseId: string, userId: string) {
    const { error } = await supabaseAdmin
      .from('course_members')
      .delete()
      .eq('course_id', courseId)
      .eq('user_id', userId);

    if (error) throw error;
    return true;
  }

  static async getCourseMembers(courseId: string, query: ParsedQuery) {
    const { data, count, error } = await supabaseAdmin
      .from('course_members')
      .select('*, profiles(id, full_name, email, avatar_url, role)', { count: 'exact' })
      .eq('course_id', courseId)
      .order('joined_at', { ascending: false })
      .range(query.offset, query.offset + query.limit - 1);

    if (error) throw error;
    return { items: data || [], total: count || 0 };
  }
}
