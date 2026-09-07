// ==============================================================================
// ZankoAI Calendar & Notification Type Definitions
// ==============================================================================

export type CalendarEventType =
  | 'class'
  | 'exam'
  | 'assignment_deadline'
  | 'reminder'
  | 'university_event'
  | 'personal_study_event'
  | 'lecture'
  | 'assignment'
  | 'personal';

export interface CalendarEventRecord {
  id: string;
  user_id: string;
  course_id?: string | null;
  title: string;
  description?: string | null;
  event_type: CalendarEventType;
  start_time: string; // Stored in UTC (ISO-8601)
  end_time: string;   // Stored in UTC (ISO-8601)
  is_all_day: boolean;
  location?: string | null;
  timezone: string;
  notification_lead_minutes: number;
  recurrence_rule?: string | null;
  is_completed: boolean;
  created_at: string;
  updated_at: string;
}

export interface CalendarEventCreateInput {
  course_id?: string;
  title: string;
  description?: string;
  event_type?: CalendarEventType;
  start_time: string;
  end_time: string;
  is_all_day?: boolean;
  location?: string;
  timezone?: string;
  notification_lead_minutes?: number;
  recurrence_rule?: string;
}

export interface CalendarEventUpdateInput {
  course_id?: string | null;
  title?: string;
  description?: string | null;
  event_type?: CalendarEventType;
  start_time?: string;
  end_time?: string;
  is_all_day?: boolean;
  location?: string | null;
  timezone?: string;
  notification_lead_minutes?: number;
  recurrence_rule?: string | null;
  is_completed?: boolean;
}

export type NotificationType =
  | 'assignment_reminder'
  | 'exam_reminder'
  | 'teacher_announcement'
  | 'system_notification'
  | 'subscription_notification'
  | 'system'
  | 'broadcast'
  | 'vip'
  | 'academic'
  | 'reminder'
  | 'security';

export interface NotificationRecord {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type: NotificationType;
  data?: Record<string, any>;
  is_read: boolean;
  read_at?: string | null;
  idempotency_key?: string | null;
  reference_id?: string | null;
  scheduled_for?: string | null;
  sent_at?: string | null;
  status: 'pending' | 'delivered' | 'failed' | 'cancelled';
  created_at: string;
}

export interface NotificationPreferencesRecord {
  user_id: string;
  assignment_reminders: boolean;
  exam_reminders: boolean;
  teacher_announcements: boolean;
  system_notifications: boolean;
  subscription_notifications: boolean;
  push_enabled: boolean;
  email_enabled: boolean;
  lead_time_minutes: number;
  timezone: string;
  created_at: string;
  updated_at: string;
}

export interface NotificationDeviceRecord {
  id: string;
  user_id: string;
  fcm_token: string;
  device_id?: string | null;
  platform: 'android' | 'ios' | 'web';
  app_version?: string | null;
  is_active: boolean;
  last_seen_at: string;
  created_at: string;
  updated_at: string;
}

export interface ScheduledNotificationJobData {
  userId: string;
  title: string;
  body: string;
  type: NotificationType;
  data?: Record<string, any>;
  idempotencyKey: string;
  referenceId?: string;
  scheduledFor: string;
}

export interface NotificationPaginationResult {
  items: NotificationRecord[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  unreadCount: number;
}
