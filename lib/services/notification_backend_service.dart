// ==============================================================================
// ZankoAI Notification Backend Service — Client Layer
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/app_notification_model.dart';

class NotificationBackendService {
  final Dio? _customDio;
  NotificationBackendService({Dio? dio}) : _customDio = dio;
  NotificationBackendService._() : _customDio = null;
  static final NotificationBackendService instance = NotificationBackendService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Fetches paginated notifications for the authenticated user.
  Future<Map<String, dynamic>> listNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'type': ?type,
      'is_read': ?isRead,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: queryParams,
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((e) => AppNotificationModel.fromJson(e))
        .toList();

    return {
      'items': items,
      'total': data['total'] ?? items.length,
      'page': data['page'] ?? page,
      'limit': data['limit'] ?? limit,
      'totalPages': data['totalPages'] ?? 1,
      'unreadCount': data['unreadCount'] ?? 0,
    };
  }

  /// Marks a specific notification as read.
  Future<AppNotificationModel> markAsRead(String id) async {
    final response = await _dio.patch<Map<String, dynamic>>('/notifications/$id/read');
    final data = response.data!['data'] as Map<String, dynamic>;
    return AppNotificationModel.fromJson(data);
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    await _dio.post<Map<String, dynamic>>('/notifications/read-all');
  }

  /// Deletes a notification.
  Future<void> deleteNotification(String id) async {
    await _dio.delete<Map<String, dynamic>>('/notifications/$id');
  }

  /// Retrieves user notification preferences.
  Future<NotificationPreferencesModel> getPreferences() async {
    final response = await _dio.get<Map<String, dynamic>>('/notifications/preferences');
    final data = response.data!['data'] as Map<String, dynamic>;
    return NotificationPreferencesModel.fromJson(data);
  }

  /// Updates user notification preferences.
  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/notifications/preferences',
      data: preferences.toMap(),
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return NotificationPreferencesModel.fromJson(data);
  }

  /// Registers a device token for push notifications.
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceId,
    String? appVersion,
  }) async {
    final payload = <String, dynamic>{
      'fcm_token': fcmToken,
      'platform': platform,
      'device_id': ?deviceId,
      'app_version': ?appVersion,
    };

    await _dio.post<Map<String, dynamic>>('/notifications/devices', data: payload);
  }

  /// Unregisters a device token on user logout.
  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _dio.delete<Map<String, dynamic>>('/notifications/devices/$fcmToken');
  }
}
