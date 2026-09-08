// ==============================================================================
// ZankoAI Notification Service — Asynchronous, Idempotent, Preference-Aware
// Supported Categories:
//   1. assignment_reminder (assignment reminder)
//   2. exam_reminder (exam reminder)
//   3. announcement / teacher_announcement (announcement)
//   4. ai_job_completion (AI job completion)
//   5. subscription_activated (subscription activated)
//   6. subscription_expiring (subscription expiring)
//   7. payment_result (payment result)
//   8. system_notification (system notification)
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { notificationQueue } from '../queues/queue.js';
import { logger } from '../config/logger.js';
import { redis } from '../config/redis.js';
import { providerRegistry } from './notification_providers/index.js';
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
    announcements: true,
    ai_job_completion: true,
    subscription_notifications: true,
    payment_updates: true,
    system_notifications: true,
    push_enabled: true,
    email_enabled: false,
    lead_time_minutes: 60,
    timezone: 'Asia/Baghdad',
  };

  /**
   * Schedules or dispatches a notification via BullMQ background queue.
   * Enforces recipient preferences and strictly prevents duplicate notifications
   * using dual-layer deduplication (Redis lock + Postgres unique constraint).
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

    // 2. Layer 1 Deduplication: Fast Redis Check (24-hour TTL)
    try {
      const redisKey = `zanko:notif_dedup:${idempotencyKey}`;
      const acquired = await redis.set(redisKey, '1', 'EX', 86400, 'NX');
      if (!acquired) {
        logger.info(`[NotificationService] Duplicate suppressed via Redis lock: ${idempotencyKey}`);
        return { scheduled: false, reason: 'duplicate_idempotency_key' };
      }
    } catch (redisErr) {
      // If Redis is temporarily unavailable, gracefully fall back to DB check
      logger.warn(`[NotificationService] Redis dedup check skipped:`, redisErr);
    }

    // 3. Layer 2 Deduplication: Check if already stored in database
    const { data: existing } = await supabaseAdmin
      .from('notifications')
      .select('id, status')
      .eq('idempotency_key', idempotencyKey)
      .maybeSingle();

    if (existing) {
      logger.info(`[NotificationService] Duplicate suppressed via DB idempotency key: ${idempotencyKey}`);
      return { scheduled: false, reason: 'duplicate_idempotency_key' };
    }

    // 4. Verify recipient's notification preferences
    const prefs = await this.getPreferences(userId);
    if (!this.isCategoryEnabled(prefs, type)) {
      logger.info(`[NotificationService] Suppressed notification for user ${userId} due to preference: ${type}`);
      return { scheduled: false, reason: 'preference_disabled' };
    }

    // 5. Calculate delay for scheduled alerts (event reminders, deadlines, etc.)
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

    // 6. Asynchronously enqueue to BullMQ with jobId deduplication
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
    let pushReceipt = null;
    if (prefs.push_enabled) {
      pushReceipt = await this.dispatchPushToUserDevices(userId, title, body, type, data);
    }

    return { delivered: true, notificationId: inserted?.id, pushReceipt };
  }

  /**
   * Dispatches push notifications to all active registered devices of a user
   * through the decoupled Notification Provider abstraction layer.
   * Also cleans up any invalid/expired device tokens reported by the provider.
   */
  static async dispatchPushToUserDevices(
    userId: string,
    title: string,
    body: string,
    type: string,
    data?: Record<string, any>
  ) {
    try {
      const { data: devices, error } = await supabaseAdmin
        .from('notification_devices')
        .select('id, fcm_token, platform, device_id')
        .eq('user_id', userId)
        .eq('is_active', true);

      if (error) {
        logger.error(`[NotificationPush] Failed to query user devices for ${userId}:`, error);
        return null;
      }

      if (!devices || devices.length === 0) {
        logger.info(`[NotificationPush] No active registered devices found for user ${userId}`);
        return null;
      }

      const tokens = devices.map((d) => d.fcm_token).filter(Boolean);
      if (tokens.length === 0) return null;

      logger.info(
        `[NotificationPush] Dispatched push alert via provider to ${tokens.length} device(s) for user ${userId}: "${title}"`
      );

      // Get active notification provider from registry (FCM, Mock, etc.)
      const provider = providerRegistry.getProvider();
      const receipt = await provider.send({
        tokens,
        title,
        body,
        type,
        data: data || {},
        priority: 'high',
      });

      // Handle invalid / stale tokens reported by provider
      const deadTokens = receipt.failedTokens
        .filter((f) => f.isInvalidToken)
        .map((f) => f.token);

      if (deadTokens.length > 0) {
        await this.deactivateInvalidTokens(deadTokens);
      }

      return receipt;
    } catch (err) {
      logger.error(`[NotificationPush] Error during push dispatch:`, err);
      return null;
    }
  }

  /**
   * Deactivates dead/unregistered tokens so background workers do not waste resources.
   */
  static async deactivateInvalidTokens(tokens: string[]): Promise<void> {
    if (!tokens || tokens.length === 0) return;
    try {
      logger.info(`[NotificationService] Automatically deactivating ${tokens.length} invalid token(s)`);
      await supabaseAdmin
        .from('notification_devices')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .in('fcm_token', tokens);
    } catch (err) {
      logger.error(`[NotificationService] Error deactivating invalid tokens:`, err);
    }
  }

  /**
   * Determines if a notification category is active according to user preferences.
   * Supports all 8 required production types.
   */
  static isCategoryEnabled(prefs: NotificationPreferencesRecord, type: NotificationType): boolean {
    switch (type) {
      case 'assignment_reminder':
        return prefs.assignment_reminders;
      case 'exam_reminder':
        return prefs.exam_reminders;
      case 'announcement':
      case 'teacher_announcement':
        return (prefs.announcements ?? prefs.teacher_announcements) !== false;
      case 'ai_job_completion':
        return prefs.ai_job_completion !== false;
      case 'subscription_activated':
      case 'subscription_expiring':
      case 'subscription_notification':
        return prefs.subscription_notifications !== false;
      case 'payment_result':
        return prefs.payment_updates !== false;
      case 'system_notification':
      case 'system':
      case 'broadcast':
      case 'security':
      case 'vip':
      case 'academic':
      case 'reminder':
        return prefs.system_notifications !== false;
      default:
        return true;
    }
  }

  /**
   * Paginated listing of notifications for a user.
   * Returns: id, user_id, type, title, body, data, read_at, created_at
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
      .select('id, user_id, type, title, body, data, is_read, read_at, created_at, status', { count: 'exact' })
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
      items: (items || []) as any,
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
    const now = new Date().toISOString();
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true, read_at: now })
      .eq('id', id)
      .eq('user_id', userId)
      .select('id, user_id, type, title, body, data, is_read, read_at, created_at')
      .maybeSingle();

    if (error) throw error;
    return data;
  }

  /**
   * Marks all unread notifications for a user as read.
   */
  static async markAllNotificationsRead(userId: string) {
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('notifications')
      .update({ is_read: true, read_at: now })
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
   * Registers or refreshes a device token for push delivery.
   * Multi-device support: users can have multiple registered devices.
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
   * Lists active devices for a user.
   */
  static async listDevices(userId: string) {
    const { data, error } = await supabaseAdmin
      .from('notification_devices')
      .select('id, platform, device_id, app_version, is_active, last_seen_at, created_at')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('last_seen_at', { ascending: false });

    if (error) throw error;
    return data || [];
  }

  /**
   * Deactivates or removes a device by record UUID, device_id, or token.
   * Used for explicit device removal or user logout.
   */
  static async deleteDevice(userId: string, identifier: string) {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(identifier);

    let query = supabaseAdmin
      .from('notification_devices')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('user_id', userId);

    if (isUuid) {
      query = query.or(`id.eq.${identifier},device_id.eq.${identifier},fcm_token.eq.${identifier}`);
    } else {
      query = query.or(`device_id.eq.${identifier},fcm_token.eq.${identifier}`);
    }

    const { data, error } = await query.select();
    if (error) throw error;

    return {
      success: true,
      deactivatedCount: data?.length || 0,
    };
  }

  /**
   * Deactivates a device token upon user logout (backward-compatible alias).
   */
  static async unregisterDevice(userId: string, fcmToken: string) {
    return this.deleteDevice(userId, fcmToken);
  }
}
