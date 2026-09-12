import { supabaseAdmin } from '../../../config/supabase.js';
import {
  AcademicReport,
  CreateReportDTO,
  UpdateReportDTO,
  ReportSection,
  Seminar,
  CreateSeminarDTO,
  UpdateSeminarDTO,
  SeminarSection,
  AcademicQueryOptions,
} from './reports_seminars.interface.js';

export class ReportsSeminarsRepository {
  // ─── Reports Repository ───────────────────────────────────────────────────

  static async createReport(userId: string, dto: CreateReportDTO): Promise<AcademicReport> {
    const { sections, ...reportData } = dto;

    const { data: report, error: reportError } = await supabaseAdmin
      .from('reports')
      .insert({
        user_id: userId,
        title: reportData.title,
        subject: reportData.subject,
        topic: reportData.topic,
        language: reportData.language || 'ku',
        description: reportData.description,
        content: reportData.content,
        student_name: reportData.student_name,
        supervisor_name: reportData.supervisor_name,
        university_name: reportData.university_name,
        department_name: reportData.department_name,
        academic_year: reportData.academic_year,
        writing_style: reportData.writing_style || 'academicComprehensive',
        length_level: reportData.length_level || 'words4000',
        logo_url: reportData.logo_url,
        status: reportData.status || 'completed',
        metadata: reportData.metadata || {},
      })
      .select('*')
      .single();

    if (reportError || !report) {
      throw new Error(`Failed to create report in Supabase: ${reportError?.message}`);
    }

    // Insert sections if provided
    let insertedSections: ReportSection[] = [];
    if (sections && sections.length > 0) {
      const sectionRows = sections.map((sec) => ({
        report_id: report.id,
        section_order: sec.section_order,
        title: sec.title,
        content: sec.content,
        bullet_points: sec.bullet_points || [],
        page_number: sec.page_number || 1,
        key_takeaway: sec.key_takeaway,
      }));

      const { data: secs, error: secError } = await supabaseAdmin
        .from('report_sections')
        .insert(sectionRows)
        .select('*')
        .order('section_order', { ascending: true });

      if (secError) {
        throw new Error(`Failed to insert report sections: ${secError.message}`);
      }
      insertedSections = secs || [];
    }

    return {
      ...report,
      sections: insertedSections,
    };
  }

  static async getReportsByUser(
    userId: string,
    options: AcademicQueryOptions = {}
  ): Promise<{ reports: AcademicReport[]; total: number }> {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(50, Math.max(1, options.limit || 20));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('reports')
      .select('*', { count: 'exact' })
      .eq('user_id', userId);

    if (options.search && options.search.trim().length > 0) {
      query = query.ilike('title', `%${options.search.trim()}%`);
    }

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.language) {
      query = query.eq('language', options.language);
    }

    const { data, count, error } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to query reports: ${error.message}`);
    }

    return {
      reports: data || [],
      total: count || 0,
    };
  }

  static async getReportById(reportId: string): Promise<AcademicReport | null> {
    const { data: report, error } = await supabaseAdmin
      .from('reports')
      .select('*')
      .eq('id', reportId)
      .maybeSingle();

    if (error || !report) return null;

    const { data: sections } = await supabaseAdmin
      .from('report_sections')
      .select('*')
      .eq('report_id', reportId)
      .order('section_order', { ascending: true });

    return {
      ...report,
      sections: sections || [],
    };
  }

  static async updateReport(
    reportId: string,
    dto: UpdateReportDTO
  ): Promise<AcademicReport | null> {
    const { sections, ...updateFields } = dto;

    const { data: updated, error } = await supabaseAdmin
      .from('reports')
      .update(updateFields)
      .eq('id', reportId)
      .select('*')
      .single();

    if (error || !updated) {
      throw new Error(`Failed to update report: ${error?.message}`);
    }

    // Update sections if provided
    if (sections && sections.length > 0) {
      // Upsert or replace sections
      await supabaseAdmin.from('report_sections').delete().eq('report_id', reportId);

      const sectionRows = sections.map((sec) => ({
        report_id: reportId,
        section_order: sec.section_order,
        title: sec.title,
        content: sec.content,
        bullet_points: sec.bullet_points || [],
        page_number: sec.page_number || 1,
        key_takeaway: sec.key_takeaway,
      }));

      await supabaseAdmin.from('report_sections').insert(sectionRows);
    }

    return this.getReportById(reportId);
  }

  static async deleteReport(reportId: string): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('reports')
      .delete()
      .eq('id', reportId);

    if (error) {
      throw new Error(`Failed to delete report: ${error.message}`);
    }
    return true;
  }

  // ─── Seminars Repository ──────────────────────────────────────────────────

  static async createSeminar(userId: string, dto: CreateSeminarDTO): Promise<Seminar> {
    const { slides, ...seminarData } = dto;

    const { data: seminar, error: semError } = await supabaseAdmin
      .from('seminars')
      .insert({
        user_id: userId,
        title: seminarData.title,
        subject: seminarData.subject,
        topic: seminarData.topic,
        language: seminarData.language || 'ku',
        description: seminarData.description,
        content: seminarData.content,
        status: seminarData.status || 'completed',
        metadata: seminarData.metadata || {},
      })
      .select('*')
      .single();

    if (semError || !seminar) {
      throw new Error(`Failed to create seminar: ${semError?.message}`);
    }

    let insertedSlides: SeminarSection[] = [];
    if (slides && slides.length > 0) {
      const slideRows = slides.map((s) => ({
        seminar_id: seminar.id,
        section_order: s.section_order,
        title: s.title,
        content: s.content,
        bullet_points: s.bullet_points || [],
        speaker_notes: s.speaker_notes,
        visual_prompt: s.visual_prompt,
        image_url: s.image_url,
        category_tag: s.category_tag,
      }));

      const { data: sls, error: slError } = await supabaseAdmin
        .from('seminar_sections')
        .insert(slideRows)
        .select('*')
        .order('section_order', { ascending: true });

      if (slError) {
        throw new Error(`Failed to insert seminar slides: ${slError.message}`);
      }
      insertedSlides = sls || [];
    }

    return {
      ...seminar,
      slides: insertedSlides,
    };
  }

  static async getSeminarsByUser(
    userId: string,
    options: AcademicQueryOptions = {}
  ): Promise<{ seminars: Seminar[]; total: number }> {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(50, Math.max(1, options.limit || 20));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('seminars')
      .select('*', { count: 'exact' })
      .eq('user_id', userId);

    if (options.search && options.search.trim().length > 0) {
      query = query.ilike('title', `%${options.search.trim()}%`);
    }

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.language) {
      query = query.eq('language', options.language);
    }

    const { data, count, error } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to query seminars: ${error.message}`);
    }

    return {
      seminars: data || [],
      total: count || 0,
    };
  }

  static async getSeminarById(seminarId: string): Promise<Seminar | null> {
    const { data: seminar, error } = await supabaseAdmin
      .from('seminars')
      .select('*')
      .eq('id', seminarId)
      .maybeSingle();

    if (error || !seminar) return null;

    const { data: slides } = await supabaseAdmin
      .from('seminar_sections')
      .select('*')
      .eq('seminar_id', seminarId)
      .order('section_order', { ascending: true });

    return {
      ...seminar,
      slides: slides || [],
    };
  }

  static async updateSeminar(
    seminarId: string,
    dto: UpdateSeminarDTO
  ): Promise<Seminar | null> {
    const { slides, ...updateFields } = dto;

    const { data: updated, error } = await supabaseAdmin
      .from('seminars')
      .update(updateFields)
      .eq('id', seminarId)
      .select('*')
      .single();

    if (error || !updated) {
      throw new Error(`Failed to update seminar: ${error?.message}`);
    }

    if (slides && slides.length > 0) {
      await supabaseAdmin.from('seminar_sections').delete().eq('seminar_id', seminarId);

      const slideRows = slides.map((s) => ({
        seminar_id: seminarId,
        section_order: s.section_order,
        title: s.title,
        content: s.content,
        bullet_points: s.bullet_points || [],
        speaker_notes: s.speaker_notes,
        visual_prompt: s.visual_prompt,
        image_url: s.image_url,
        category_tag: s.category_tag,
      }));

      await supabaseAdmin.from('seminar_sections').insert(slideRows);
    }

    return this.getSeminarById(seminarId);
  }

  static async deleteSeminar(seminarId: string): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('seminars')
      .delete()
      .eq('id', seminarId);

    if (error) {
      throw new Error(`Failed to delete seminar: ${error.message}`);
    }
    return true;
  }
}
