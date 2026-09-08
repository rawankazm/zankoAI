// ==============================================================================
// ZankoAI Calendar Service — Client Layer
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/calendar_event_model.dart';

class CalendarService {
  final Dio? _customDio;
  CalendarService({Dio? dio}) : _customDio = dio;
  CalendarService._() : _customDio = null;
  static final CalendarService instance = CalendarService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Fetches calendar events for the authenticated user with optional filters.
  Future<List<CalendarEventModel>> listEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    String? courseId,
  }) async {
    final queryParams = <String, dynamic>{
      if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
      'event_type': ?eventType,
      'course_id': ?courseId,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/calendar/events',
      queryParameters: queryParams,
    );

    final items = response.data?['data'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => CalendarEventModel.fromJson(e))
        .toList();
  }

  /// Fetches a single event by ID.
  Future<CalendarEventModel> getEvent(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/calendar/events/$id',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CalendarEventModel.fromJson(data);
  }

  /// Creates a new calendar event, converting start & end times to strict UTC.
  Future<CalendarEventModel> createEvent({
    required String title,
    String? description,
    String? courseId,
    String eventType = 'personal_study_event',
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String timezone = 'Asia/Baghdad',
    int notificationLeadMinutes = 30,
    String? recurrenceRule,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (description != null) 'description': description.trim(),
      'course_id': ?courseId,
      'event_type': eventType,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      if (location != null) 'location': location.trim(),
      'timezone': timezone,
      'notification_lead_minutes': notificationLeadMinutes,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule.trim(),
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/calendar/events',
      data: payload,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return CalendarEventModel.fromJson(data);
  }

  /// Updates an existing calendar event.
  Future<CalendarEventModel> updateEvent(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/calendar/events/$id',
      data: updates,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return CalendarEventModel.fromJson(data);
  }

  /// Deletes a calendar event.
  Future<void> deleteEvent(String id) async {
    await _dio.delete<Map<String, dynamic>>('/calendar/events/$id');
  }
}
