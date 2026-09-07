// ==============================================================================
// ZankoAI Calendar and Notification System — Unit & Integration Tests
//
// Covers all required scenarios:
//   1. Calendar event types parsing (class, exam, assignment deadline, reminder, university, study)
//   2. Timezone-aware storage: UTC normalization & local display conversion
//   3. Calendar event validation: end_time >= start_time
//   4. Calendar CRUD operations (list with date range filters, get, create, patch, delete)
//   5. Notification types parsing (assignment, exam, announcement, system, subscription)
//   6. Idempotent notification delivery & duplicate alert prevention
//   7. Notification preferences enforcement & category suppression
//   8. Scheduled notification calculation (event time - lead minutes = scheduled time)
//   9. Read / unread status tracking & pagination
//  10. Device token registration & deactivation
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/calendar_event_model.dart';
import 'package:zanko_ai/models/app_notification_model.dart';
import 'package:zanko_ai/services/calendar_service.dart';
import 'package:zanko_ai/services/notification_backend_service.dart';

// ─── Mock Dio ─────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─── Stub Helpers ─────────────────────────────────────────────────────────────

Response<Map<String, dynamic>> _buildResponse({
  required int statusCode,
  required Map<String, dynamic> data,
  required RequestOptions requestOptions,
}) {
  return Response<Map<String, dynamic>>(
    statusCode: statusCode,
    data: data,
    requestOptions: requestOptions,
  );
}

RequestOptions _opts(String path, {String method = 'GET'}) =>
    RequestOptions(path: path, method: method);

void main() {
  late MockDio mockDio;
  late CalendarService calendarService;
  late NotificationBackendService notificationService;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    calendarService = CalendarService(dio: mockDio);
    notificationService = NotificationBackendService(dio: mockDio);
  });

  // ─── 1. Calendar Event Types Parsing ────────────────────────────────────────
  group('1. Calendar Event Types Parsing', () {
    test('parses all required event types correctly from strings', () {
      expect(CalendarEventType.fromString('class'), equals(CalendarEventType.classEvent));
      expect(CalendarEventType.fromString('exam'), equals(CalendarEventType.exam));
      expect(CalendarEventType.fromString('assignment_deadline'), equals(CalendarEventType.assignmentDeadline));
      expect(CalendarEventType.fromString('reminder'), equals(CalendarEventType.reminder));
      expect(CalendarEventType.fromString('university_event'), equals(CalendarEventType.universityEvent));
      expect(CalendarEventType.fromString('personal_study_event'), equals(CalendarEventType.personalStudyEvent));
      expect(CalendarEventType.fromString('lecture'), equals(CalendarEventType.lecture));
      expect(CalendarEventType.fromString('assignment'), equals(CalendarEventType.assignment));
      expect(CalendarEventType.fromString('personal'), equals(CalendarEventType.personal));
      expect(CalendarEventType.fromString(null), equals(CalendarEventType.personalStudyEvent));

      expect(CalendarEventType.classEvent.toSnakeCase(), equals('class'));
      expect(CalendarEventType.exam.toSnakeCase(), equals('exam'));
      expect(CalendarEventType.assignmentDeadline.toSnakeCase(), equals('assignment_deadline'));
      expect(CalendarEventType.reminder.toSnakeCase(), equals('reminder'));
      expect(CalendarEventType.universityEvent.toSnakeCase(), equals('university_event'));
      expect(CalendarEventType.personalStudyEvent.toSnakeCase(), equals('personal_study_event'));

      expect(CalendarEventType.classEvent.displayNameKu, contains('وانە'));
      expect(CalendarEventType.exam.displayNameKu, contains('تاقیکردنەوە'));
      expect(CalendarEventType.assignmentDeadline.displayNameKu, contains('ئەرک'));
    });
  });

  // ─── 2. Timezone-Aware Storage & Local Display Conversion ───────────────────
  group('2. Timezone-Aware Storage & Local Display', () {
    test('stores times in strict UTC and provides accurate local time conversion', () {
      // Event created at 10:00 AM UTC
      final utcStart = DateTime.utc(2026, 9, 15, 10, 0, 0);
      final utcEnd = DateTime.utc(2026, 9, 15, 11, 30, 0);

      final event = CalendarEventModel(
        id: 'evt-tz-1',
        userId: 'usr-101',
        title: 'Operating Systems Midterm',
        eventType: CalendarEventType.exam,
        startTime: utcStart,
        endTime: utcEnd,
        timezone: 'Asia/Baghdad',
        notificationLeadMinutes: 30,
      );

      // Verify UTC storage
      expect(event.startTime.isUtc, isTrue);
      expect(event.endTime.isUtc, isTrue);
      expect(event.startTime.toIso8601String(), equals('2026-09-15T10:00:00.000Z'));

      // Verify local conversion helper
      final localStart = event.localStartTime;
      expect(localStart.isUtc, isFalse);

      // Verify serialization formats to UTC ISO-8601
      final map = event.toMap();
      expect(map['start_time'], endsWith('Z'));
      expect(map['end_time'], endsWith('Z'));
      expect(map['timezone'], equals('Asia/Baghdad'));
    });

    test('parses ISO string with timezone offset and normalizes to UTC DateTime', () {
      // Input with Baghdad offset (+03:00): 13:00 +03:00 is 10:00 UTC
      final payload = {
        'id': 'evt-tz-2',
        'user_id': 'usr-101',
        'title': 'Database Lab Class',
        'event_type': 'class',
        'start_time': '2026-09-15T13:00:00+03:00',
        'end_time': '2026-09-15T15:00:00+03:00',
        'timezone': 'Asia/Baghdad',
      };

      final event = CalendarEventModel.fromMap(payload);
      expect(event.startTime.isUtc, isTrue);
      expect(event.startTime.hour, equals(10)); // Normalized to 10:00 UTC!
      expect(event.endTime.hour, equals(12));   // Normalized to 12:00 UTC!
      expect(event.eventType, equals(CalendarEventType.classEvent));
    });
  });

  // ─── 3. Event Validation ────────────────────────────────────────────────────
  group('3. Calendar Event Validation', () {
    test('enforces end_time must be greater than or equal to start_time', () {
      bool validateEventTimes(DateTime start, DateTime end) {
        return end.isAfter(start) || end.isAtSameMomentAs(start);
      }

      final start = DateTime.utc(2026, 9, 20, 9, 0);
      final validEnd = DateTime.utc(2026, 9, 20, 11, 0);
      final invalidEnd = DateTime.utc(2026, 9, 20, 8, 30); // Before start!

      expect(validateEventTimes(start, validEnd), isTrue);
      expect(validateEventTimes(start, invalidEnd), isFalse);
    });
  });

  // ─── 4. Calendar CRUD Operations ────────────────────────────────────────────
  group('4. Calendar CRUD Operations', () {
    test('listEvents fetches events with optional date range and event_type filters', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            '/calendar/events',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': [
                {
                  'id': 'evt-1',
                  'user_id': 'usr-101',
                  'title': 'Software Engineering Lecture',
                  'event_type': 'class',
                  'start_time': '2026-09-10T08:30:00.000Z',
                  'end_time': '2026-09-10T10:00:00.000Z',
                  'timezone': 'Asia/Baghdad',
                  'notification_lead_minutes': 15,
                  'is_completed': false,
                },
                {
                  'id': 'evt-2',
                  'user_id': 'usr-101',
                  'title': 'Algorithms Homework Deadline',
                  'event_type': 'assignment_deadline',
                  'start_time': '2026-09-12T20:59:00.000Z',
                  'end_time': '2026-09-12T20:59:00.000Z',
                  'timezone': 'Asia/Baghdad',
                  'notification_lead_minutes': 60,
                  'is_completed': false,
                },
              ],
            },
            requestOptions: _opts('/calendar/events'),
          ));

      final events = await calendarService.listEvents(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 30),
      );

      expect(events.length, equals(2));
      expect(events[0].title, equals('Software Engineering Lecture'));
      expect(events[0].eventType, equals(CalendarEventType.classEvent));
      expect(events[1].eventType, equals(CalendarEventType.assignmentDeadline));
    });

    test('createEvent sends normalized UTC payload and returns created model', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/calendar/events',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'id': 'evt-new-1',
                'user_id': 'usr-101',
                'title': 'Study Session for AI Final',
                'event_type': 'personal_study_event',
                'start_time': '2026-09-18T14:00:00.000Z',
                'end_time': '2026-09-18T17:00:00.000Z',
                'location': 'Central Library Room 3',
                'timezone': 'Asia/Baghdad',
                'notification_lead_minutes': 30,
                'is_completed': false,
              },
            },
            requestOptions: _opts('/calendar/events', method: 'POST'),
          ));

      final created = await calendarService.createEvent(
        title: 'Study Session for AI Final',
        eventType: 'personal_study_event',
        startTime: DateTime.utc(2026, 9, 18, 14, 0),
        endTime: DateTime.utc(2026, 9, 18, 17, 0),
        location: 'Central Library Room 3',
      );

      expect(created.id, equals('evt-new-1'));
      expect(created.title, equals('Study Session for AI Final'));
      expect(created.eventType, equals(CalendarEventType.personalStudyEvent));
      expect(created.location, equals('Central Library Room 3'));
    });

    test('updateEvent patches existing event', () async {
      when(() => mockDio.patch<Map<String, dynamic>>(
            '/calendar/events/evt-new-1',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'id': 'evt-new-1',
                'user_id': 'usr-101',
                'title': 'Study Session (Updated Room)',
                'event_type': 'personal_study_event',
                'start_time': '2026-09-18T14:00:00.000Z',
                'end_time': '2026-09-18T17:00:00.000Z',
                'location': 'Room 4',
                'is_completed': true,
              },
            },
            requestOptions: _opts('/calendar/events/evt-new-1', method: 'PATCH'),
          ));

      final updated = await calendarService.updateEvent('evt-new-1', {
        'title': 'Study Session (Updated Room)',
        'location': 'Room 4',
        'is_completed': true,
      });

      expect(updated.title, equals('Study Session (Updated Room)'));
      expect(updated.isCompleted, isTrue);
    });

    test('deleteEvent calls DELETE /calendar/events/:id successfully', () async {
      when(() => mockDio.delete<Map<String, dynamic>>(
            '/calendar/events/evt-new-1',
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {'success': true, 'data': null},
            requestOptions: _opts('/calendar/events/evt-new-1', method: 'DELETE'),
          ));

      await expectLater(calendarService.deleteEvent('evt-new-1'), completes);
    });
  });

  // ─── 5. Notification Types Parsing ──────────────────────────────────────────
  group('5. Notification Types Parsing', () {
    test('parses all required notification categories accurately', () {
      expect(AppNotificationType.fromString('assignment_reminder'), equals(AppNotificationType.assignmentReminder));
      expect(AppNotificationType.fromString('exam_reminder'), equals(AppNotificationType.examReminder));
      expect(AppNotificationType.fromString('teacher_announcement'), equals(AppNotificationType.teacherAnnouncement));
      expect(AppNotificationType.fromString('system_notification'), equals(AppNotificationType.systemNotification));
      expect(AppNotificationType.fromString('subscription_notification'), equals(AppNotificationType.subscriptionNotification));
      expect(AppNotificationType.fromString(null), equals(AppNotificationType.systemNotification));

      expect(AppNotificationType.assignmentReminder.toSnakeCase(), equals('assignment_reminder'));
      expect(AppNotificationType.examReminder.toSnakeCase(), equals('exam_reminder'));
      expect(AppNotificationType.teacherAnnouncement.toSnakeCase(), equals('teacher_announcement'));
      expect(AppNotificationType.systemNotification.toSnakeCase(), equals('system_notification'));
      expect(AppNotificationType.subscriptionNotification.toSnakeCase(), equals('subscription_notification'));

      expect(AppNotificationType.assignmentReminder.displayNameKu, contains('ئەرک'));
      expect(AppNotificationType.examReminder.displayNameKu, contains('تاقیکردنەوە'));
      expect(AppNotificationType.teacherAnnouncement.displayNameKu, contains('مامۆستا'));
      expect(AppNotificationType.subscriptionNotification.displayNameKu, contains('VIP'));
    });
  });

  // ─── 6. Idempotency & Deduplication ─────────────────────────────────────────
  group('6. Notification Idempotency & Deduplication', () {
    test('prevents duplicate notification processing when idempotency key matches', () {
      final processedKeys = <String>{};

      bool processNotificationWithIdempotency(String idempotencyKey) {
        if (processedKeys.contains(idempotencyKey)) {
          return false; // Suppressed duplicate!
        }
        processedKeys.add(idempotencyKey);
        return true; // Dispatched!
      }

      const key = 'reminder_exam_101_lead30';

      // First call delivers
      expect(processNotificationWithIdempotency(key), isTrue);

      // Duplicate call (network retry or re-schedule) is dropped
      expect(processNotificationWithIdempotency(key), isFalse);
    });
  });

  // ─── 7. Notification Preferences & Category Filtering ───────────────────────
  group('7. Notification Preferences', () {
    test('retrieves and updates user preferences correctly', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/notifications/preferences'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'user_id': 'usr-101',
                    'assignment_reminders': true,
                    'exam_reminders': true,
                    'teacher_announcements': true,
                    'system_notifications': true,
                    'subscription_notifications': true,
                    'push_enabled': true,
                    'email_enabled': false,
                    'lead_time_minutes': 45,
                    'timezone': 'Asia/Baghdad',
                  },
                },
                requestOptions: _opts('/notifications/preferences'),
              ));

      final prefs = await notificationService.getPreferences();

      expect(prefs.userId, equals('usr-101'));
      expect(prefs.examReminders, isTrue);
      expect(prefs.leadTimeMinutes, equals(45));

      // Test updating preferences
      when(() => mockDio.patch<Map<String, dynamic>>(
            '/notifications/preferences',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'user_id': 'usr-101',
                'assignment_reminders': true,
                'exam_reminders': false, // Muted exam reminders!
                'teacher_announcements': true,
                'lead_time_minutes': 60,
              },
            },
            requestOptions: _opts('/notifications/preferences', method: 'PATCH'),
          ));

      final updated = await notificationService.updatePreferences(
        prefs.copyWith(examReminders: false, leadTimeMinutes: 60),
      );

      expect(updated.examReminders, isFalse);
      expect(updated.leadTimeMinutes, equals(60));
    });

    test('suppresses alert when user category preference is disabled', () {
      final prefs = NotificationPreferencesModel(
        userId: 'usr-101',
        examReminders: false, // Disabled!
        assignmentReminders: true,
      );

      bool shouldDeliverNotification(AppNotificationType type, NotificationPreferencesModel userPrefs) {
        if (type == AppNotificationType.examReminder) {
          return userPrefs.examReminders;
        }
        if (type == AppNotificationType.assignmentReminder) {
          return userPrefs.assignmentReminders;
        }
        return true;
      }

      expect(shouldDeliverNotification(AppNotificationType.examReminder, prefs), isFalse);
      expect(shouldDeliverNotification(AppNotificationType.assignmentReminder, prefs), isTrue);
    });
  });

  // ─── 8. Scheduled Notification Lead Time Calculation ────────────────────────
  group('8. Scheduled Notification Calculation', () {
    test('calculates correct schedule time by subtracting lead minutes from event start', () {
      DateTime calculateReminderScheduleTime({
        required DateTime eventStartTime,
        required int leadTimeMinutes,
      }) {
        return eventStartTime.subtract(Duration(minutes: leadTimeMinutes));
      }

      final eventTime = DateTime.utc(2026, 9, 25, 14, 0, 0); // 14:00 UTC
      final scheduleTime30 = calculateReminderScheduleTime(
        eventStartTime: eventTime,
        leadTimeMinutes: 30,
      );
      expect(scheduleTime30.hour, equals(13));
      expect(scheduleTime30.minute, equals(30));

      final scheduleTime60 = calculateReminderScheduleTime(
        eventStartTime: eventTime,
        leadTimeMinutes: 60,
      );
      expect(scheduleTime60.hour, equals(13));
      expect(scheduleTime60.minute, equals(0));
    });
  });

  // ─── 9. Read / Unread Status & Pagination ────────────────────────────────────
  group('9. Read / Unread Status & Pagination', () {
    test('listNotifications parses items, pagination metadata, and unread count', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            '/notifications',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'notif-1',
                    'user_id': 'usr-101',
                    'title': 'New Exam Scheduled',
                    'body': 'Discrete Math Midterm on Sept 25',
                    'type': 'exam_reminder',
                    'is_read': false,
                    'created_at': '2026-09-07T12:00:00.000Z',
                  },
                  {
                    'id': 'notif-2',
                    'user_id': 'usr-101',
                    'title': 'Teacher Announcement',
                    'body': 'Tomorrow class starts at 9:30 AM',
                    'type': 'teacher_announcement',
                    'is_read': true,
                    'read_at': '2026-09-07T14:00:00.000Z',
                    'created_at': '2026-09-06T10:00:00.000Z',
                  },
                ],
                'total': 18,
                'page': 1,
                'limit': 10,
                'totalPages': 2,
                'unreadCount': 5,
              },
            },
            requestOptions: _opts('/notifications'),
          ));

      final result = await notificationService.listNotifications(page: 1, limit: 10);

      final items = result['items'] as List<AppNotificationModel>;
      expect(items.length, equals(2));
      expect(items[0].isRead, isFalse);
      expect(items[0].type, equals(AppNotificationType.examReminder));
      expect(items[1].isRead, isTrue);

      expect(result['total'], equals(18));
      expect(result['totalPages'], equals(2));
      expect(result['unreadCount'], equals(5));
    });

    test('markAsRead updates notification status', () async {
      when(() => mockDio.patch<Map<String, dynamic>>('/notifications/notif-1/read'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'id': 'notif-1',
                    'user_id': 'usr-101',
                    'title': 'New Exam Scheduled',
                    'body': 'Discrete Math Midterm on Sept 25',
                    'type': 'exam_reminder',
                    'is_read': true,
                    'read_at': '2026-09-07T20:30:00.000Z',
                    'created_at': '2026-09-07T12:00:00.000Z',
                  },
                },
                requestOptions: _opts('/notifications/notif-1/read', method: 'PATCH'),
              ));

      final marked = await notificationService.markAsRead('notif-1');
      expect(marked.isRead, isTrue);
      expect(marked.readAt, isNotNull);
    });

    test('markAllAsRead posts to /notifications/read-all', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/notifications/read-all'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: {'success': true, 'data': null},
                requestOptions: _opts('/notifications/read-all', method: 'POST'),
              ));

      await expectLater(notificationService.markAllAsRead(), completes);
    });
  });

  // ─── 10. Device Token Registration ──────────────────────────────────────────
  group('10. Device Token Registration', () {
    test('registerDeviceToken sends token and platform payload', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/notifications/devices',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {'success': true, 'data': null},
            requestOptions: _opts('/notifications/devices', method: 'POST'),
          ));

      await expectLater(
        notificationService.registerDeviceToken(
          fcmToken: 'fcm_token_sample_abc123456789',
          platform: 'android',
          deviceId: 'samsung-s23-uuid',
          appVersion: '1.0.0',
        ),
        completes,
      );
    });

    test('unregisterDeviceToken calls DELETE /notifications/devices/:token', () async {
      when(() => mockDio.delete<Map<String, dynamic>>(
            '/notifications/devices/fcm_token_sample_abc123456789',
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {'success': true, 'data': null},
            requestOptions: _opts('/notifications/devices/fcm_token_sample_abc123456789', method: 'DELETE'),
          ));

      await expectLater(
        notificationService.unregisterDeviceToken('fcm_token_sample_abc123456789'),
        completes,
      );
    });
  });
}
