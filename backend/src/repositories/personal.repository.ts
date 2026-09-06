import { supabaseAdmin } from '../config/supabase.js';
import { ParsedQuery } from '../utils/queryBuilder.js';

export class PersonalRepository {
  // ─── Calendar Events ───
  static async listCalendarEvents(userId: string, startTime?: string, endTime?: string) {
    let req = supabaseAdmin.from('calendar_events').select('*').eq('user_id', userId);

    if (startTime) {
      req = req.gte('end_time', startTime);
    }
    if (endTime) {
      req = req.lte('start_time', endTime);
    }

    const { data, error } = await req.order('start_time', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  static async getCalendarEventById(id: string) {
    const { data, error } = await supabaseAdmin.from('calendar_events').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data;
  }

  static async createCalendarEvent(userId: string, data: any) {
    const { data: res, error } = await supabaseAdmin
      .from('calendar_events')
      .insert([{ ...data, user_id: userId }])
      .select()
      .maybeSingle();

    if (error) throw error;
    return res;
  }

  static async updateCalendarEvent(id: string, data: any) {
    const { data: res, error } = await supabaseAdmin
      .from('calendar_events')
      .update(data)
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error) throw error;
    return res;
  }

  static async deleteCalendarEvent(id: string) {
    const { error } = await supabaseAdmin.from('calendar_events').delete().eq('id', id);
    if (error) throw error;
    return true;
  }

  // ─── Progress Tracking ───
  static async getLectureProgress(userId: string, lectureId: string) {
    const { data, error } = await supabaseAdmin
      .from('lecture_progress')
      .select('*')
      .eq('user_id', userId)
      .eq('lecture_id', lectureId)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  static async updateLectureProgress(userId: string, lectureId: string, progressPercent: number, isCompleted: boolean) {
    const { data, error } = await supabaseAdmin
      .from('lecture_progress')
      .upsert(
        {
          user_id: userId,
          lecture_id: lectureId,
          progress_percent: progressPercent,
          is_completed: isCompleted,
          last_read_at: new Date().toISOString(),
          completed_at: isCompleted ? new Date().toISOString() : null,
        },
        { onConflict: 'lecture_id,user_id' }
      )
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  static async getCourseStudyProgress(userId: string, courseId: string) {
    const { data, error } = await supabaseAdmin
      .from('study_progress')
      .select('*')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  // ─── Notifications ───
  static async listNotifications(userId: string, query: ParsedQuery) {
    const req = supabaseAdmin
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;

    // Count unread
    const { count: unreadCount } = await supabaseAdmin
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('is_read', false);

    return {
      items: data || [],
      total: count || 0,
      unreadCount: unreadCount || 0,
    };
  }

  static async markNotificationRead(id: string, userId: string) {
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  static async markAllNotificationsRead(userId: string) {
    const { error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', userId)
      .eq('is_read', false);

    if (error) throw error;
    return true;
  }

  static async deleteNotification(id: string, userId: string) {
    const { error } = await supabaseAdmin
      .from('notifications')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

    if (error) throw error;
    return true;
  }
}
