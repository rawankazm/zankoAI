// ==============================================================================
// ZankoAI Calendar & Notification Request Validators
// ==============================================================================

import { z } from 'zod';

const calendarEventTypeEnum = z.enum([
  'class',
  'exam',
  'assignment_deadline',
  'reminder',
  'university_event',
  'personal_study_event',
  'lecture',
  'assignment',
  'personal',
]);

const notificationTypeEnum = z.enum([
  'assignment_reminder',
  'exam_reminder',
  'announcement',
  'teacher_announcement',
  'ai_job_completion',
  'subscription_activated',
  'subscription_expiring',
  'payment_result',
  'system_notification',
  'subscription_notification',
  'system',
  'broadcast',
  'vip',
  'academic',
  'reminder',
  'security',
]);

export const createCalendarEventSchema = z
  .object({
    course_id: z.string().uuid().optional().nullable(),
    title: z.string().trim().min(1, 'Title is required').max(200),
    description: z.string().trim().max(2000).optional().nullable(),
    event_type: calendarEventTypeEnum.default('personal_study_event'),
    start_time: z.string().datetime({ message: 'start_time must be a valid ISO-8601 datetime' }),
    end_time: z.string().datetime({ message: 'end_time must be a valid ISO-8601 datetime' }),
    is_all_day: z.boolean().default(false),
    location: z.string().trim().max(255).optional().nullable(),
    timezone: z.string().trim().default('Asia/Baghdad'),
    notification_lead_minutes: z.number().int().min(0).max(10080).default(30),
    recurrence_rule: z.string().trim().max(255).optional().nullable(),
  })
  .refine(
    (data) => new Date(data.end_time).getTime() >= new Date(data.start_time).getTime(),
    {
      message: 'end_time cannot be earlier than start_time',
      path: ['end_time'],
    }
  );

export const updateCalendarEventSchema = z
  .object({
    course_id: z.string().uuid().optional().nullable(),
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().trim().max(2000).optional().nullable(),
    event_type: calendarEventTypeEnum.optional(),
    start_time: z.string().datetime().optional(),
    end_time: z.string().datetime().optional(),
    is_all_day: z.boolean().optional(),
    location: z.string().trim().max(255).optional().nullable(),
    timezone: z.string().trim().optional(),
    notification_lead_minutes: z.number().int().min(0).max(10080).optional(),
    recurrence_rule: z.string().trim().max(255).optional().nullable(),
    is_completed: z.boolean().optional(),
  })
  .refine(
    (data) => {
      if (data.start_time && data.end_time) {
        return new Date(data.end_time).getTime() >= new Date(data.start_time).getTime();
      }
      return true;
    },
    {
      message: 'end_time cannot be earlier than start_time',
      path: ['end_time'],
    }
  );

export const registerDeviceSchema = z.object({
  fcm_token: z.string().trim().min(10, 'FCM token must be at least 10 characters'),
  platform: z.enum(['android', 'ios', 'web']),
  device_id: z.string().trim().max(100).optional().nullable(),
  app_version: z.string().trim().max(50).optional().nullable(),
});

export const updateNotificationPreferencesSchema = z.object({
  assignment_reminders: z.boolean().optional(),
  exam_reminders: z.boolean().optional(),
  teacher_announcements: z.boolean().optional(),
  announcements: z.boolean().optional(),
  ai_job_completion: z.boolean().optional(),
  payment_updates: z.boolean().optional(),
  system_notifications: z.boolean().optional(),
  subscription_notifications: z.boolean().optional(),
  push_enabled: z.boolean().optional(),
  email_enabled: z.boolean().optional(),
  lead_time_minutes: z.number().int().min(0).max(10080).optional(),
  timezone: z.string().trim().optional(),
});

export const scheduleNotificationSchema = z.object({
  user_id: z.string().uuid().optional(),
  title: z.string().trim().min(1).max(200),
  body: z.string().trim().min(1).max(2000),
  type: notificationTypeEnum.default('system_notification'),
  data: z.record(z.any()).optional().nullable(),
  scheduled_for: z.string().datetime().optional().nullable(),
  idempotency_key: z.string().trim().max(100).optional().nullable(),
  reference_id: z.string().uuid().optional().nullable(),
});
