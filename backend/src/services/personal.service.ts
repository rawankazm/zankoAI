import { PersonalRepository } from '../repositories/personal.repository.js';
import { ParsedQuery, QueryHelper } from '../utils/queryBuilder.js';
import { NotFoundError, ForbiddenError } from '../utils/apiError.js';
import { supabaseAdmin } from '../config/supabase.js';

export class PersonalService {
  // ─── Calendar ───
  static async getCalendarEvents(userId: string, startTime?: string, endTime?: string) {
    return PersonalRepository.listCalendarEvents(userId, startTime, endTime);
  }

  static async createCalendarEvent(userId: string, data: any) {
    return PersonalRepository.createCalendarEvent(userId, data);
  }

  static async updateCalendarEvent(id: string, userId: string, userRole: string, data: any) {
    const existing = await PersonalRepository.getCalendarEventById(id);
    if (!existing) throw new NotFoundError('Calendar event not found');

    if (userRole !== 'admin' && existing.user_id !== userId) {
      throw new ForbiddenError('You can only update your own calendar events');
    }

    return PersonalRepository.updateCalendarEvent(id, data);
  }

  static async deleteCalendarEvent(id: string, userId: string, userRole: string) {
    const existing = await PersonalRepository.getCalendarEventById(id);
    if (!existing) throw new NotFoundError('Calendar event not found');

    if (userRole !== 'admin' && existing.user_id !== userId) {
      throw new ForbiddenError('You can only delete your own calendar events');
    }

    return PersonalRepository.deleteCalendarEvent(id);
  }

  // ─── Progress ───
  static async trackLectureProgress(userId: string, lectureId: string, progressPercent: number, isCompleted: boolean) {
    return PersonalRepository.updateLectureProgress(userId, lectureId, progressPercent, isCompleted);
  }

  static async getUserCourseProgress(userId: string, courseId: string) {
    return PersonalRepository.getCourseStudyProgress(userId, courseId);
  }

  // ─── Notifications ───
  static async getNotifications(userId: string, query: ParsedQuery) {
    const { items, total, unreadCount } = await PersonalRepository.listNotifications(userId, query);
    const paginated = QueryHelper.formatResult(items, total, query.page, query.limit);
    return {
      ...paginated,
      unreadCount,
    };
  }

  static async markNotificationRead(id: string, userId: string) {
    return PersonalRepository.markNotificationRead(id, userId);
  }

  static async markAllNotificationsRead(userId: string) {
    return PersonalRepository.markAllNotificationsRead(userId);
  }

  static async deleteNotification(id: string, userId: string) {
    return PersonalRepository.deleteNotification(id, userId);
  }
}
