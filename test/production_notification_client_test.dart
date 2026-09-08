// ==============================================================================
// ZankoAI Production Push Notification Client Tests
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/app_notification_model.dart';
import 'package:zanko_ai/services/notification_backend_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late NotificationBackendService service;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    service = NotificationBackendService(dio: mockDio);
  });

  // ─── 1. All 8 Required Production Notification Types ────────────────────────
  group('1. Production Notification Types Parsing', () {
    test('parses all 8 required production types accurately from string', () {
      expect(
        AppNotificationType.fromString('assignment_reminder'),
        equals(AppNotificationType.assignmentReminder),
      );
      expect(
        AppNotificationType.fromString('exam_reminder'),
        equals(AppNotificationType.examReminder),
      );
      expect(
        AppNotificationType.fromString('announcement'),
        equals(AppNotificationType.announcement),
      );
      expect(
        AppNotificationType.fromString('teacher_announcement'),
        equals(AppNotificationType.teacherAnnouncement),
      );
      expect(
        AppNotificationType.fromString('ai_job_completion'),
        equals(AppNotificationType.aiJobCompletion),
      );
      expect(
        AppNotificationType.fromString('subscription_activated'),
        equals(AppNotificationType.subscriptionActivated),
      );
      expect(
        AppNotificationType.fromString('subscription_expiring'),
        equals(AppNotificationType.subscriptionExpiring),
      );
      expect(
        AppNotificationType.fromString('payment_result'),
        equals(AppNotificationType.paymentResult),
      );
      expect(
        AppNotificationType.fromString('system_notification'),
        equals(AppNotificationType.systemNotification),
      );

      // Serialization to snake_case
      expect(
        AppNotificationType.assignmentReminder.toSnakeCase(),
        equals('assignment_reminder'),
      );
      expect(
        AppNotificationType.examReminder.toSnakeCase(),
        equals('exam_reminder'),
      );
      expect(
        AppNotificationType.announcement.toSnakeCase(),
        equals('announcement'),
      );
      expect(
        AppNotificationType.aiJobCompletion.toSnakeCase(),
        equals('ai_job_completion'),
      );
      expect(
        AppNotificationType.subscriptionActivated.toSnakeCase(),
        equals('subscription_activated'),
      );
      expect(
        AppNotificationType.subscriptionExpiring.toSnakeCase(),
        equals('subscription_expiring'),
      );
      expect(
        AppNotificationType.paymentResult.toSnakeCase(),
        equals('payment_result'),
      );
      expect(
        AppNotificationType.systemNotification.toSnakeCase(),
        equals('system_notification'),
      );

      // Kurdish display names
      expect(
        AppNotificationType.aiJobCompletion.displayNameKu,
        contains('ژیری دەستکرد'),
      );
      expect(
        AppNotificationType.subscriptionActivated.displayNameKu,
        contains('VIP'),
      );
      expect(
        AppNotificationType.paymentResult.displayNameKu,
        contains('پارەدان'),
      );
    });
  });

  // ─── 2. Notification Model JSON Mapping ─────────────────────────────────────
  group('2. AppNotificationModel Data Mapping', () {
    test(
      'deserializes complete production notification object with read_at',
      () {
        final now = DateTime.utc(2026, 9, 8, 12, 0, 0);
        final json = {
          'id': 'notif-uuid-101',
          'user_id': 'user-uuid-202',
          'title': 'Flashcard Generation Complete',
          'body': 'Your AI flashcards for Cardiology are ready for study.',
          'type': 'ai_job_completion',
          'data': {'course_id': 'crs-med-01', 'cards_count': 15},
          'is_read': true,
          'read_at': now.toIso8601String(),
          'created_at': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        };

        final model = AppNotificationModel.fromJson(json);

        expect(model.id, equals('notif-uuid-101'));
        expect(model.userId, equals('user-uuid-202'));
        expect(model.title, equals('Flashcard Generation Complete'));
        expect(model.type, equals(AppNotificationType.aiJobCompletion));
        expect(model.data?['cards_count'], equals(15));
        expect(model.isRead, isTrue);
        expect(model.readAt, equals(now));
      },
    );
  });

  // ─── 3. Notification Preferences Model ──────────────────────────────────────
  group('3. NotificationPreferencesModel Granular Settings', () {
    test('defaults all categories to enabled and handles overrides', () {
      final defaultPrefs = NotificationPreferencesModel(userId: 'usr-303');

      expect(defaultPrefs.assignmentReminders, isTrue);
      expect(defaultPrefs.examReminders, isTrue);
      expect(defaultPrefs.announcements, isTrue);
      expect(defaultPrefs.aiJobCompletion, isTrue);
      expect(defaultPrefs.subscriptionNotifications, isTrue);
      expect(defaultPrefs.paymentUpdates, isTrue);
      expect(defaultPrefs.systemNotifications, isTrue);
      expect(defaultPrefs.pushEnabled, isTrue);
      expect(defaultPrefs.leadTimeMinutes, equals(60));

      final customized = defaultPrefs.copyWith(
        aiJobCompletion: false,
        paymentUpdates: false,
      );

      expect(customized.aiJobCompletion, isFalse);
      expect(customized.paymentUpdates, isFalse);
      expect(customized.examReminders, isTrue);

      final map = customized.toMap();
      expect(map['ai_job_completion'], isFalse);
      expect(map['payment_updates'], isFalse);
      expect(map['user_id'], equals('usr-303'));
    });
  });

  // ─── 4. Endpoints: GET /api/notifications ───────────────────────────────────
  group('4. GET /api/notifications Client Endpoint', () {
    test('fetches paginated notifications and parses unreadCount', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'items': [
                {
                  'id': 'notif-1',
                  'user_id': 'usr-1',
                  'title': 'Exam Reminder',
                  'body': 'Database Exam in 2 hours',
                  'type': 'exam_reminder',
                  'is_read': false,
                  'created_at': DateTime.now().toIso8601String(),
                },
              ],
              'total': 1,
              'page': 1,
              'limit': 20,
              'totalPages': 1,
              'unreadCount': 1,
            },
          },
          requestOptions: RequestOptions(path: '/notifications'),
        ),
      );

      final result = await service.listNotifications(page: 1, limit: 20);

      expect(result['total'], equals(1));
      expect(result['unreadCount'], equals(1));
      final items = result['items'] as List<AppNotificationModel>;
      expect(items.length, equals(1));
      expect(items.first.type, equals(AppNotificationType.examReminder));
    });
  });

  // ─── 5. Endpoints: PATCH /api/notifications/:id/read ────────────────────────
  group('5. PATCH /api/notifications/:id/read Client Endpoint', () {
    test('marks notification as read and returns updated model', () async {
      when(
        () =>
            mockDio.patch<Map<String, dynamic>>('/notifications/notif-1/read'),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': 'notif-1',
              'user_id': 'usr-1',
              'title': 'Payment Result',
              'body': 'Your FIB payment of 10,000 IQD succeeded.',
              'type': 'payment_result',
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            },
          },
          requestOptions: RequestOptions(path: '/notifications/notif-1/read'),
        ),
      );

      final updated = await service.markAsRead('notif-1');

      expect(updated.id, equals('notif-1'));
      expect(updated.isRead, isTrue);
      expect(updated.type, equals(AppNotificationType.paymentResult));
    });
  });

  // ─── 6. Endpoints: POST /api/devices & DELETE /api/devices/:id ──────────────
  group('6. Device Registration & Removal Client Endpoints', () {
    test('POST /devices registers device token for current user', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/devices',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': 'device-row-uuid-999',
              'fcm_token': 'test_fcm_token_device_abc',
              'platform': 'android',
              'is_active': true,
            },
          },
          requestOptions: RequestOptions(path: '/devices'),
        ),
      );

      final device = await service.registerDevice(
        fcmToken: 'test_fcm_token_device_abc',
        platform: 'android',
        deviceId: 'device-hardware-id-123',
        appVersion: '1.4.0',
      );

      expect(device['id'], equals('device-row-uuid-999'));
      expect(device['is_active'], isTrue);
      expect(device['platform'], equals('android'));
    });

    test('DELETE /devices/:id unregisters device upon logout', () async {
      when(
        () => mockDio.delete<Map<String, dynamic>>(
          '/devices/device-row-uuid-999',
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'success': true,
            'message': 'Device unregistered successfully',
          },
          requestOptions: RequestOptions(path: '/devices/device-row-uuid-999'),
        ),
      );

      await expectLater(service.deleteDevice('device-row-uuid-999'), completes);
    });

    test('GET /devices returns list of active user devices', () async {
      when(() => mockDio.get<Map<String, dynamic>>('/devices')).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'success': true,
            'data': [
              {
                'id': 'dev-1',
                'platform': 'android',
                'device_id': 'galaxy-s24',
                'is_active': true,
              },
              {
                'id': 'dev-2',
                'platform': 'ios',
                'device_id': 'iphone-16-pro',
                'is_active': true,
              },
            ],
          },
          requestOptions: RequestOptions(path: '/devices'),
        ),
      );

      final devices = await service.listDevices();
      expect(devices.length, equals(2));
      expect(devices[0]['platform'], equals('android'));
      expect(devices[1]['platform'], equals('ios'));
    });
  });
}
