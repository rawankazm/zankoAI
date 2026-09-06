import { Request, Response } from 'express';
import { PersonalService } from '../services/personal.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { QueryHelper } from '../utils/queryBuilder.js';

export class PersonalController {
  // ─── Calendar ───
  static async listCalendarEvents(req: Request, res: Response): Promise<Response> {
    const startTime = req.query.start_time as string;
    const endTime = req.query.end_time as string;
    const events = await PersonalService.getCalendarEvents(req.user!.id, startTime, endTime);
    return ResponseFormatter.success(res, events);
  }

  static async createCalendarEvent(req: Request, res: Response): Promise<Response> {
    const event = await PersonalService.createCalendarEvent(req.user!.id, req.body);
    return ResponseFormatter.created(res, event, 'Calendar event created successfully');
  }

  static async updateCalendarEvent(req: Request, res: Response): Promise<Response> {
    const event = await PersonalService.updateCalendarEvent(
      req.params.id,
      req.user!.id,
      req.profile!.role,
      req.body
    );
    return ResponseFormatter.success(res, event, 'Calendar event updated successfully');
  }

  static async deleteCalendarEvent(req: Request, res: Response): Promise<Response> {
    await PersonalService.deleteCalendarEvent(req.params.id, req.user!.id, req.profile!.role);
    return ResponseFormatter.success(res, null, 'Calendar event deleted successfully');
  }

  // ─── Progress ───
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

  // ─── Notifications ───
  static async listNotifications(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['created_at'],
      defaultSortField: 'created_at',
      defaultSortAsc: false,
    });
    const result = await PersonalService.getNotifications(req.user!.id, query);
    return ResponseFormatter.success(res, result);
  }

  static async markRead(req: Request, res: Response): Promise<Response> {
    const notification = await PersonalService.markNotificationRead(req.params.id, req.user!.id);
    return ResponseFormatter.success(res, notification, 'Notification marked as read');
  }

  static async markAllRead(req: Request, res: Response): Promise<Response> {
    await PersonalService.markAllNotificationsRead(req.user!.id);
    return ResponseFormatter.success(res, null, 'All notifications marked as read');
  }

  static async deleteNotification(req: Request, res: Response): Promise<Response> {
    await PersonalService.deleteNotification(req.params.id, req.user!.id);
    return ResponseFormatter.success(res, null, 'Notification deleted successfully');
  }
}
