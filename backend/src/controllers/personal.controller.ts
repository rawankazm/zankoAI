import { Request, Response } from 'express';
import { CalendarService } from '../services/calendar.service.js';
import { NotificationService } from '../services/notification.service.js';
import { PersonalService } from '../services/personal.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { NotificationType } from '../types/calendar_notification.types.js';
import { ForbiddenError } from '../utils/apiError.js';

export class PersonalController {
  // ─── Calendar Events ───
  static async listCalendarEvents(req: Request, res: Response): Promise<Response> {
    const startDate = (req.query.start_date || req.query.start_time) as string | undefined;
    const endDate = (req.query.end_date || req.query.end_time) as string | undefined;
    const eventType = req.query.event_type as string | undefined;
    const courseId = req.query.course_id as string | undefined;

    const events = await CalendarService.listEvents(req.user!.id, {
      startDate,
      endDate,
      eventType,
      courseId,
    });
    return ResponseFormatter.success(res, events);
  }

  static async getCalendarEvent(req: Request, res: Response): Promise<Response> {
    const event = await CalendarService.getEventById(req.params.id, req.user!.id);
    if (!event) {
      return ResponseFormatter.notFound(res, 'Calendar event not found');
    }
    return ResponseFormatter.success(res, event);
  }

  static async createCalendarEvent(req: Request, res: Response): Promise<Response> {
    const event = await CalendarService.createEvent(req.user!.id, req.body);
    return ResponseFormatter.created(res, event, 'Calendar event created successfully');
  }

  static async updateCalendarEvent(req: Request, res: Response): Promise<Response> {
    const event = await CalendarService.updateEvent(req.params.id, req.user!.id, req.body);
    return ResponseFormatter.success(res, event, 'Calendar event updated successfully');
  }

  static async deleteCalendarEvent(req: Request, res: Response): Promise<Response> {
    await CalendarService.deleteEvent(req.params.id, req.user!.id);
    return ResponseFormatter.success(res, null, 'Calendar event deleted successfully');
  }

  // ─── Progress Tracking ───
  static async trackLectureProgress(req: Request, res: Response): Promise<Response> {
    const { lecture_id, progress_percent, is_completed } = req.body;
    const record = await PersonalService.trackLectureProgress(
      req.user!.id,
      lecture_id,
      progress_percent,
      is_completed
    );
    return ResponseFormatter.success(res, record, 'Progress updated successfully');
  }

  static async getCourseProgress(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId;
    const progress = await PersonalService.getUserCourseProgress(req.user!.id, courseId);
    return ResponseFormatter.success(res, progress);
  }

  // ─── Notifications (Paginated & Preference-Aware) ───
  static async listNotifications(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 20;
    const type = req.query.type as NotificationType | undefined;
    let isRead: boolean | undefined;
    if (req.query.is_read !== undefined) {
      isRead = req.query.is_read === 'true' || req.query.is_read === '1';
    }

    const result = await NotificationService.listNotifications(req.user!.id, {
      page,
      limit,
      type,
      isRead,
    });
    return ResponseFormatter.success(res, result);
  }

  static async markRead(req: Request, res: Response): Promise<Response> {
    const notification = await NotificationService.markNotificationRead(req.params.id, req.user!.id);
    return ResponseFormatter.success(res, notification, 'Notification marked as read');
  }

  static async markAllRead(req: Request, res: Response): Promise<Response> {
    await NotificationService.markAllNotificationsRead(req.user!.id);
    return ResponseFormatter.success(res, null, 'All notifications marked as read');
  }

  static async deleteNotification(req: Request, res: Response): Promise<Response> {
    await PersonalService.deleteNotification(req.params.id, req.user!.id);
    return ResponseFormatter.success(res, null, 'Notification deleted successfully');
  }

  // ─── Notification Preferences ───
  static async getPreferences(req: Request, res: Response): Promise<Response> {
    const preferences = await NotificationService.getPreferences(req.user!.id);
    return ResponseFormatter.success(res, preferences);
  }

  static async updatePreferences(req: Request, res: Response): Promise<Response> {
    const updated = await NotificationService.updatePreferences(req.user!.id, req.body);
    return ResponseFormatter.success(res, updated, 'Notification preferences updated');
  }

  // ─── Device Tokens ───
  static async registerDevice(req: Request, res: Response): Promise<Response> {
    const device = await NotificationService.registerDevice(req.user!.id, req.body);
    return ResponseFormatter.success(res, device, 'Device registered successfully');
  }

  static async unregisterDevice(req: Request, res: Response): Promise<Response> {
    const token = req.params.token || req.body.fcm_token;
    await NotificationService.unregisterDevice(req.user!.id, token);
    return ResponseFormatter.success(res, null, 'Device unregistered successfully');
  }

  // ─── Asynchronous Notification Scheduling ───
  static async scheduleNotification(req: Request, res: Response): Promise<Response> {
    const isAdmin = (req.user as any)?.role === 'admin' || (req as any).profile?.role === 'admin';
    if (!isAdmin && req.body.user_id && req.body.user_id !== req.user!.id) {
      throw new ForbiddenError('Only administrators can schedule notifications for other users');
    }
    const targetUserId = isAdmin ? (req.body.user_id || req.user!.id) : req.user!.id;

    const result = await NotificationService.scheduleNotification({
      userId: targetUserId,
      title: req.body.title,
      body: req.body.body,
      type: req.body.type,
      data: req.body.data,
      idempotencyKey: req.body.idempotency_key,
      referenceId: req.body.reference_id,
      scheduledFor: req.body.scheduled_for,
    });
    return ResponseFormatter.success(res, result, 'Notification scheduled successfully');
  }
}
