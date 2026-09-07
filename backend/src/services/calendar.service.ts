// ==============================================================================
// ZankoAI Calendar Service — Timezone-Aware, UTC Backend Storage, Auto-Reminders
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import {
  CalendarEventRecord,
  CalendarEventCreateInput,
  CalendarEventUpdateInput,
  NotificationType,
} from '../types/calendar_notification.types.js';
import { NotificationService } from './notification.service.js';

export class CalendarService {
  /**
   * Lists calendar events for a user with optional date range and category filters.
   */
  static async listEvents(
    userId: string,
    options: {
      startDate?: string;
      endDate?: string;
      eventType?: string;
      courseId?: string;
    }
  ): Promise<CalendarEventRecord[]> {
    let query = supabaseAdmin
      .from('calendar_events')
      .select('*')
      .eq('user_id', userId);

    if (options.startDate) {
      const utcStart = new Date(options.startDate).toISOString();
      query = query.gte('end_time', utcStart);
    }
    if (options.endDate) {
      const utcEnd = new Date(options.endDate).toISOString();
      query = query.lte('start_time', utcEnd);
    }
    if (options.eventType) {
      query = query.eq('event_type', options.eventType);
    }
    if (options.courseId) {
      query = query.eq('course_id', options.courseId);
    }

    const { data, error } = await query.order('start_time', { ascending: true });
    if (error) throw error;
    return (data || []) as CalendarEventRecord[];
  }

  /**
   * Retrieves a single event by ID, enforcing ownership.
   */
  static async getEventById(id: string, userId: string): Promise<CalendarEventRecord | null> {
    const { data, error } = await supabaseAdmin
      .from('calendar_events')
      .select('*')
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();

    if (error) throw error;
    return data as CalendarEventRecord | null;
  }

  /**
   * Creates a calendar event, normalizing all datetimes to UTC.
   * If notification_lead_minutes > 0, schedules an automatic background reminder.
   */
  static async createEvent(
    userId: string,
    input: CalendarEventCreateInput
  ): Promise<CalendarEventRecord> {
    // 1. Normalize datetimes to strict UTC ISO-8601 strings
    const startUtc = new Date(input.start_time).toISOString();
    const endUtc = new Date(input.end_time).toISOString();

    if (new Date(endUtc).getTime() < new Date(startUtc).getTime()) {
      throw new Error('End time cannot be earlier than start time');
    }

    const leadMinutes = typeof input.notification_lead_minutes === 'number' ? input.notification_lead_minutes : 30;

    const payload = {
      user_id: userId,
      course_id: input.course_id || null,
      title: input.title.trim(),
      description: input.description?.trim() || null,
      event_type: input.event_type || 'personal_study_event',
      start_time: startUtc,
      end_time: endUtc,
      is_all_day: input.is_all_day || false,
      location: input.location?.trim() || null,
      timezone: input.timezone || 'Asia/Baghdad',
      notification_lead_minutes: leadMinutes,
      recurrence_rule: input.recurrence_rule?.trim() || null,
      is_completed: false,
    };

    const { data: created, error } = await supabaseAdmin
      .from('calendar_events')
      .insert([payload])
      .select()
      .maybeSingle();

    if (error) throw error;
    const event = created as CalendarEventRecord;

    // 2. Schedule background reminder if lead time is configured
    if (leadMinutes > 0) {
      await this.scheduleEventReminder(event);
    }

    return event;
  }

  /**
   * Updates an existing calendar event and reschedules reminders if times changed.
   */
  static async updateEvent(
    id: string,
    userId: string,
    updates: CalendarEventUpdateInput
  ): Promise<CalendarEventRecord> {
    const existing = await this.getEventById(id, userId);
    if (!existing) {
      throw new Error('Event not found or unauthorized');
    }

    const startUtc = updates.start_time ? new Date(updates.start_time).toISOString() : existing.start_time;
    const endUtc = updates.end_time ? new Date(updates.end_time).toISOString() : existing.end_time;

    if (new Date(endUtc).getTime() < new Date(startUtc).getTime()) {
      throw new Error('End time cannot be earlier than start time');
    }

    const payload: Partial<CalendarEventRecord> = {
      updated_at: new Date().toISOString(),
    };

    if (updates.title !== undefined) payload.title = updates.title.trim();
    if (updates.description !== undefined) payload.description = updates.description?.trim() || null;
    if (updates.course_id !== undefined) payload.course_id = updates.course_id || null;
    if (updates.event_type !== undefined) payload.event_type = updates.event_type;
    if (updates.start_time !== undefined) payload.start_time = startUtc;
    if (updates.end_time !== undefined) payload.end_time = endUtc;
    if (updates.is_all_day !== undefined) payload.is_all_day = updates.is_all_day;
    if (updates.location !== undefined) payload.location = updates.location?.trim() || null;
    if (updates.timezone !== undefined) payload.timezone = updates.timezone;
    if (updates.notification_lead_minutes !== undefined) payload.notification_lead_minutes = updates.notification_lead_minutes;
    if (updates.recurrence_rule !== undefined) payload.recurrence_rule = updates.recurrence_rule?.trim() || null;
    if (updates.is_completed !== undefined) payload.is_completed = updates.is_completed;

    const { data: updated, error } = await supabaseAdmin
      .from('calendar_events')
      .update(payload)
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .maybeSingle();

    if (error) throw error;
    const resultEvent = updated as CalendarEventRecord;

    // Reschedule reminder if time or lead minutes updated
    if (updates.start_time !== undefined || updates.notification_lead_minutes !== undefined) {
      if (resultEvent.notification_lead_minutes > 0) {
        await this.scheduleEventReminder(resultEvent);
      }
    }

    return resultEvent;
  }

  /**
   * Deletes a calendar event.
   */
  static async deleteEvent(id: string, userId: string): Promise<boolean> {
    const existing = await this.getEventById(id, userId);
    if (!existing) {
      throw new Error('Event not found or unauthorized');
    }

    const { error } = await supabaseAdmin
      .from('calendar_events')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

    if (error) throw error;
    return true;
  }

  /**
   * Schedules a delayed BullMQ notification job for an event reminder.
   */
  private static async scheduleEventReminder(event: CalendarEventRecord) {
    try {
      const eventStartTime = new Date(event.start_time).getTime();
      const leadMs = (event.notification_lead_minutes || 30) * 60 * 1000;
      const scheduledTime = new Date(eventStartTime - leadMs);

      // Map event type to notification type
      let notifType: NotificationType = 'reminder';
      if (event.event_type === 'exam') {
        notifType = 'exam_reminder';
      } else if (event.event_type === 'assignment_deadline' || event.event_type === 'assignment') {
        notifType = 'assignment_reminder';
      } else if (event.event_type === 'class' || event.event_type === 'lecture') {
        notifType = 'system_notification';
      }

      const idempotencyKey = `reminder_${event.id}_lead${event.notification_lead_minutes}`;

      await NotificationService.scheduleNotification({
        userId: event.user_id,
        title: `بیرهێنانەوە: ${event.title}`,
        body: `ڕووداوەکەت (${event.title}) دوای ${event.notification_lead_minutes} خولەکی تر دەستپێدەکات.`,
        type: notifType,
        idempotencyKey,
        referenceId: event.id,
        scheduledFor: scheduledTime.toISOString(),
        data: {
          eventId: event.id,
          eventType: event.event_type,
          startTime: event.start_time,
          location: event.location,
        },
      });
    } catch (err) {
      logger.error(`[CalendarService] Failed to schedule reminder for event ${event.id}:`, err);
    }
  }
}
