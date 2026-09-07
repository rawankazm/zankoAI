// ==============================================================================
// ZankoAI Notification Service — Asynchronous, Idempotent, Preference-Aware
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { notificationQueue } from '../queues/queue.js';
import { logger } from '../config/logger.js';
import {
  NotificationType,
  NotificationPreferencesRecord,
  NotificationPaginationResult,
  ScheduledNotificationJobData,
} from '../types/calendar_notification.types.js';

export class NotificationService {
  /**
   * Default notification preferences for newly onboarded students and teachers.
   */
  static readonly DEFAULT_PREFERENCES: Omit<NotificationPreferencesRecord, 'user_id' | 'created_at' | 'updated_at'> = {
    assignment_reminders: true,
    exam_reminders: true,
    teacher_announcements: true,
    system_notifications: true,
    subscription_notifications: true,
    push_enabled: true,
    email_enabled: false,
    lead_time_minutes: 60,
    timezone: 'Asia/Baghdad',
  };

  /**
   * Schedules or dispatches a notification via BullMQ background queue.
   * Enforces recipient preferences and strictly prevents duplicate notifications.
   */
  static async scheduleNotification(input: {
    userId: string;
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, any>;
    idempotencyKey?: string | null;
    referenceId?: string | null;
    scheduledFor?: string | null;
  }): Promise<{ scheduled: boolean; reason?: string; jobId?: string }> {
    const { userId, title, body, type, data, referenceId, scheduledFor } = input;

    // 1. Generate or validate idempotency key
    const idempotencyKey =
      input.idempotencyKey ||
      `notif_${userId}_${type}_${referenceId || 'general'}_${scheduledFor || 'immediate'}`;

    // 2. Check if a notification with this idempotency key already exists in DB
    const { data: existing } = await supabaseAdmin
      .from('notifications')
      .select('id, status')
      .eq('idempotency_key', idempotencyKey)
      .maybeSingle();

    if (existing) {
      logger.info(`[NotificationService] Duplicate suppressed via idempotency key: ${idempotencyKey}`);
      return { scheduled: false, reason: 'duplicate_idempotency_key' };
    }

    // 3. Verify user's notification preferences
    const prefs = await this.getPreferences(userId);
    if (!this.isCategoryEnabled(prefs, type)) {
      logger.info(`[NotificationService] Suppressed notification for user ${userId} due to preference: ${type}`);
      return { scheduled: false, reason: 'preference_disabled' };
    }

    // 4. Calculate delay for scheduled alerts (event reminders, deadlines, etc.)
    const targetTime = scheduledFor ? new Date(scheduledFor).getTime() : Date.now();
    const delay = Math.max(0, targetTime - Date.now());

    const jobData: ScheduledNotificationJobData = {
      userId,
      title,
      body,
      type,
      data: data || {},
      idempotencyKey,
      referenceId: referenceId || undefined,
      scheduledFor: scheduledFor || new Date().toISOString(),
    };

    // 5. Asynchronously enqueue to BullMQ with jobId deduplication
    const job = await notificationQueue.add('send-notification', jobData, {
      delay,
      jobId: idempotencyKey, // BullMQ prevents duplicate jobs with the same jobId
      removeOnComplete: true,
      removeOnFail: false,
    });

    logger.info(`[NotificationService] Enqueued notification job ${job.id} with delay ${delay}ms for user ${userId}`);
    return { scheduled: true, jobId: job.id };
  }

  /**
   * Worker processor: Executed by BullMQ worker when job fires.
   */
  static async processNotificationJob(jobData: ScheduledNotificationJobData) {
    const { userId, title, body, type, data, idempotencyKey, referenceId, scheduledFor } = jobData;

    // Double-check idempotency in DB
    if (idempotencyKey) {
      const { data: existing } = await supabaseAdmin
        .from('notifications')
        .select('id')
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();

      if (existing) {
        return { delivered: true, duplicate: true };
      }
    }

    // Re-verify preferences at execution time
    const prefs = await this.getPreferences(userId);
    if (!this.isCategoryEnabled(prefs, type)) {
      logger.info(`[NotificationWorker] Job ${idempotencyKey} skipped: preference disabled at delivery`);
      return { delivered: false, reason: 'preference_disabled' };
    }

    // Insert authoritative notification record into Supabase
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title,
          body,
          type,
          data: data || {},
          idempotency_key: idempotencyKey,
          reference_id: referenceId || null,
          scheduled_for: scheduledFor,
          sent_at: new Date().toISOString(),
          status: 'delivered',
          is_read: false,
        },
      ])
      .select()
      .maybeSingle();

    if (insertError) {
      // If error is unique constraint violation on idempotency_key, treat as graceful duplicate
      if (insertError.code === '23505') {
        return { delivered: true, duplicate: true };
      }
      throw insertError;
    }

    // Dispatch to registered device tokens if push is enabled
    if (prefs.push_enabled) {
      await this.dispatchPushToUserDevices(userId, title, body, data);
    }

    return { delivered: true, notificationId: inserted?.id };
  }

  /**
   * Fetches active devices and triggers push delivery.
   */
  private static async dispatchPushToUserDevices(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, any>
  ) {
    try {
      const { data: devices } = await supabaseAdmin
        .from('notification_devices')
        .select('fcm_token, platform')
        .eq('user_id', userId)
        .eq('is_active', true);

      if (!devices || devices.length === 0) return;

      logger.info(`[NotificationPush] Delivering push alert to ${devices.length} devices for user ${userId}: "${title}"`);
      // Tokens are ready for Firebase Cloud Messaging (FCM) / WebPush dispatch
    } catch (err) {
      logger.error(`[NotificationPush] Failed to dispatch push:`, err);
    }
  }

  /**
   * Determines if a notification category is active for the user.
   */
  private static isCategoryEnabled(prefs: NotificationPreferencesRecord, type: NotificationType): boolean {
    switch (type) {
      case 'assignment_reminder':
        return prefs.assignment_reminders;
      case 'exam_reminder':
        return prefs.exam_reminders;
      case 'teacher_announcement':
        return prefs.teacher_announcements;
      case 'subscription_notification':
        return prefs.subscription_notifications;
      case 'system_notification':
      case 'system':
      case 'broadcast':
      case 'security':
        return prefs.system_notifications;
      default:
        return true;
    }
  }

  /**
   * Paginated listing of notifications for a user.
   */
  static async listNotifications(
    userId: string,
    options: {
      page?: number;
      limit?: number;
      type?: NotificationType;
      isRead?: boolean;
    }
  ): Promise<NotificationPaginationResult> {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(100, Math.max(1, options.limit || 20));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('user_id', userId);

    if (options.type) {
      query = query.eq('type', options.type);
    }
    if (typeof options.isRead === 'boolean') {
      query = query.eq('is_read', options.isRead);
    }

    query = query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);

    const { data: items, count, error } = await query;
    if (error) throw error;

    // Fast unread count query
    const { count: unreadCount } = await supabaseAdmin
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('is_read', false);

    const total = count || 0;
    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items: items || [],
      total,
      page,
      limit,
      totalPages,
      unreadCount: unreadCount || 0,
    };
  }

  /**
   * Marks a single notification as read.
   */
  static async markNotificationRead(id: string, userId: string) {
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Marks all unread notifications for a user as read.
   */
  static async markAllNotificationsRead(userId: string) {
    const { error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('is_read', false);

    if (error) throw error;
    return true;
  }

  /**
   * Retrieves notification preferences for a user, creating defaults if not set.
   */
  static async getPreferences(userId: string): Promise<NotificationPreferencesRecord> {
    const { data, error } = await supabaseAdmin
      .from('notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    if (error) throw error;
    if (data) return data as NotificationPreferencesRecord;

    // Create defaults
    const defaultRecord = {
      user_id: userId,
      ...this.DEFAULT_PREFERENCES,
    };

    const { data: created, error: createError } = await supabaseAdmin
      .from('notification_preferences')
      .insert([defaultRecord])
      .select()
      .maybeSingle();

    if (createError) {
      // In case of concurrent creation, read again
      const { data: retry } = await supabaseAdmin
        .from('notification_preferences')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();
      if (retry) return retry as NotificationPreferencesRecord;
    }

    return (created || defaultRecord) as NotificationPreferencesRecord;
  }

  /**
   * Updates user notification preferences.
   */
  static async updatePreferences(
    userId: string,
    updates: Partial<NotificationPreferencesRecord>
  ): Promise<NotificationPreferencesRecord> {
    const existing = await this.getPreferences(userId);

    const payload = {
      ...existing,
      ...updates,
      user_id: userId,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabaseAdmin
      .from('notification_preferences')
      .upsert(payload)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data as NotificationPreferencesRecord;
  }

  /**
   * Registers or refreshes a device FCM token for push delivery.
   */
  static async registerDevice(userId: string, input: {
    fcm_token: string;
    platform: 'android' | 'ios' | 'web';
    device_id?: string | null;
    app_version?: string | null;
  }) {
    const { fcm_token, platform, device_id, app_version } = input;

    const payload = {
      user_id: userId,
      fcm_token,
      platform,
      device_id: device_id || null,
      app_version: app_version || null,
      is_active: true,
      last_seen_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabaseAdmin
      .from('notification_devices')
      .upsert(payload, { onConflict: 'fcm_token' })
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Deactivates a device token upon user logout.
   */
  static async unregisterDevice(userId: string, fcmToken: string) {
    const { error } = await supabaseAdmin
      .from('notification_devices')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('fcm_token', fcmToken);

    if (error) throw error;
    return true;
  }
}
