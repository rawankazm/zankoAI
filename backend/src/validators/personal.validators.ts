import { z } from 'zod';

// ─── Calendar Events ───
export const createCalendarEventSchema = z.object({
  course_id: z.string().uuid().optional(),
  title: z.string().min(2).max(200),
  description: z.string().max(1000).optional(),
  event_type: z.enum(['exam', 'lecture', 'assignment', 'reminder', 'personal']).default('personal'),
  start_time: z.string().datetime(),
  end_time: z.string().datetime(),
  is_all_day: z.boolean().default(false),
  location: z.string().max(200).optional(),
});

export const updateCalendarEventSchema = createCalendarEventSchema.partial();

// ─── Progress Tracking ───
export const updateLectureProgressSchema = z.object({
  lecture_id: z.string().uuid(),
  progress_percent: z.number().int().min(0).max(100),
  is_completed: z.boolean().default(false),
});

// ─── Notifications ───
export const createNotificationSchema = z.object({
  user_id: z.string().uuid(),
  title: z.string().min(2).max(200),
  body: z.string().min(2).max(1000),
  type: z.enum(['system', 'broadcast', 'vip', 'academic', 'reminder', 'security']).default('system'),
  data: z.record(z.any()).optional(),
});
