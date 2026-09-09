// ==============================================================================
// ZankoAI Production Notification Controller
// Endpoints:
//   GET   /api/notifications
//   PATCH /api/notifications/:id/read
//   POST  /api/notifications/read-all
//   DELETE /api/notifications/:id
//   GET   /api/notifications/preferences
//   PATCH /api/notifications/preferences
//   POST  /api/notifications/schedule
// ==============================================================================

import { Request, Response } from 'express';
import { NotificationService } from '../services/notification.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { NotificationType } from '../types/calendar_notification.types.js';
import { ForbiddenError } from '../utils/apiError.js';

export class NotificationController {
  /**
   * GET /api/notifications
   * Returns paginated notifications for the authenticated user.
   * Supports filtering by type and read/unread status.
   */
  static async listNotifications(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 20;
    const type = req.query.type as NotificationType | undefined;

    let isRead: boolean | undefined;
    if (req.query.is_read !== undefined) {
      isRead = req.query.is_read === 'true' || req.query.is_read === '1';
    } else if (req.query.unread_only !== undefined) {
      isRead = req.query.unread_only === 'true' ? false : undefined;
    }

    const result = await NotificationService.listNotifications(req.user!.id, {
      page,
      limit,
      type,
      isRead,
    });

    return ResponseFormatter.success(res, result);
  }

  /**
   * PATCH /api/notifications/:id/read
   * Marks a specific notification as read, recording read_at timestamp.
   */
  static async markAsRead(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const notification = await NotificationService.markNotificationRead(id, req.user!.id);
    if (!notification) {
      return ResponseFormatter.notFound(res, 'Notification not found');
    }
    return ResponseFormatter.success(res, notification, 'Notification marked as read');
  }

  /**
   * POST /api/notifications/read-all
   * Marks all unread notifications for the user as read.
   */
  static async markAllAsRead(req: Request, res: Response): Promise<Response> {
    await NotificationService.markAllNotificationsRead(req.user!.id);
    return ResponseFormatter.success(res, null, 'All notifications marked as read');
  }

  /**
   * DELETE /api/notifications/:id
   * Soft deletes or removes a notification for the user.
   */
  static async deleteNotification(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const { supabaseAdmin } = await import('../config/supabase.js');
    const { error } = await supabaseAdmin
      .from('notifications')
      .delete()
      .eq('id', id)
      .eq('user_id', req.user!.id);

    if (error) throw error;
    return ResponseFormatter.success(res, null, 'Notification deleted successfully');
  }

  /**
   * GET /api/notifications/preferences
   * Retrieves user notification preferences across all 8 categories.
   */
  static async getPreferences(req: Request, res: Response): Promise<Response> {
    const preferences = await NotificationService.getPreferences(req.user!.id);
    return ResponseFormatter.success(res, preferences);
  }

  /**
   * PATCH /api/notifications/preferences
   * Updates user notification preferences.
   */
  static async updatePreferences(req: Request, res: Response): Promise<Response> {
    const updated = await NotificationService.updatePreferences(req.user!.id, req.body);
    return ResponseFormatter.success(res, updated, 'Notification preferences updated successfully');
  }

  /**
   * POST /api/notifications/schedule
   * Queues a notification job via BullMQ worker.
   */
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
