import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background handler for FCM messages when app is killed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background FCM message: ${message.messageId}');
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] ?? 'ZankoAI';
  final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

  if (title.isNotEmpty || body.isNotEmpty) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'zanko_admin_channel',
      'Admin Notifications',
      channelDescription: 'ZankoAI Admin Announcements & Messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF007AFF),
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  StreamSubscription? _adminDirectSub;
  StreamSubscription? _adminBroadcastSub;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked with payload: ${details.payload}');
      },
    );

    // Request Android 13+ & Exact Alarm permissions & create channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'zanko_admin_channel',
        'Admin Notifications',
        description: 'ZankoAI Admin Announcements & Messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // ─── Setup Google Firebase Cloud Messaging (FCM) ────────────────────────
    try {
      // 1. Request notification permissions (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Authorization Status: ${settings.authorizationStatus}');

      // 2. Set Foreground presentation options for iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Get Device FCM Token
      _fcmToken = await _fcm.getToken();
      debugPrint('Device FCM Token: $_fcmToken');

      // 4. Listen for Token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token Refreshed: $newToken');
      });

      // 5. Subscribe to default broadcast topics
      await _fcm.subscribeToTopic('all_students');
      await _fcm.subscribeToTopic('announcements');

      // 6. Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            id: message.hashCode,
            title: notification.title ?? 'ZankoAI',
            body: notification.body ?? '',
          );
        }
      });

      // 7. Handle Background Notification Tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background FCM message: ${message.data}');
      });

      // 8. Check if App was opened from a terminated state notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state FCM message: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('FCM initialization notice: $e');
    }

    _initialized = true;
  }

  /// Sync device FCM token with user profile in Firestore
  Future<void> syncUserToken(String userId, {bool isVip = false}) async {
    await init();
    if (_fcmToken == null) {
      try {
        _fcmToken = await _fcm.getToken();
      } catch (e) {
        debugPrint('Could not fetch FCM token: $e');
      }
    }

    if (_fcmToken != null && userId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': _fcmToken,
          'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'devicePlatform': defaultTargetPlatform.name,
        }, SetOptions(merge: true));

        // Manage VIP Topic Subscription
        if (isVip) {
          await _fcm.subscribeToTopic('vip_students');
        } else {
          await _fcm.unsubscribeFromTopic('vip_students');
        }
      } catch (e) {
        debugPrint('Error syncing FCM token to Firestore: $e');
      }
    }
  }

  static const String _seenDocsKey = 'zanko_seen_notified_docs_v2';
  final Set<String> _seenDocIds = {};

  /// Start listening to admin notifications from Firestore (direct_messages & notifications)
  Future<void> listenToAdminNotifications(String userId, bool isVip) async {
    _adminDirectSub?.cancel();
    _adminBroadcastSub?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(_seenDocsKey) ?? [];
    _seenDocIds.addAll(savedList);

    // 1. Direct Messages Listener (Messages sent specifically to this user)
    _adminDirectSub = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) async {
      for (var doc in snap.docs) {
        final data = doc.data();
        final docId = doc.id;
        final isRead = data['isRead'] == true;

        if (!isRead && !_seenDocIds.contains(docId)) {
          final title = data['title'] ?? data['header'] ?? data['subject'] ?? '✉️ پەیام لە ئەدمینەوە';
          final body = data['message'] ?? data['body'] ?? data['content'] ?? data['text'] ?? '';

          if (body.toString().trim().isNotEmpty || title.toString().trim().isNotEmpty) {
            await showInstantNotification(
              id: docId.hashCode,
              title: title.toString(),
              body: body.toString(),
            );
            _seenDocIds.add(docId);
            await prefs.setStringList(_seenDocsKey, _seenDocIds.toList());
          }
        }
      }
    });

    // 2. Broadcast / Targeted Notifications Listener
    _adminBroadcastSub = FirebaseFirestore.instance
        .collection('notifications')
        .snapshots()
        .listen((snap) async {
      for (var doc in snap.docs) {
        final data = doc.data();
        final docId = doc.id;
        final target = (data['target'] ?? data['to'] ?? 'all').toString().toLowerCase();
        final docUserId = data['userId'] ?? data['user_id'] ?? data['recipientId'];

        final isTargeted = target == 'all' ||
            target == 'all_students' ||
            target == 'students' ||
            (target == 'vip' && isVip) ||
            (docUserId != null && docUserId == userId);

        if (isTargeted && !_seenDocIds.contains(docId)) {
          final title = data['title'] ?? data['header'] ?? data['subject'] ?? '📢 ئاگاداریی ئەدمین';
          final body = data['body'] ?? data['message'] ?? data['content'] ?? data['text'] ?? '';

          if (body.toString().trim().isNotEmpty || title.toString().trim().isNotEmpty) {
            await showInstantNotification(
              id: docId.hashCode,
              title: title.toString(),
              body: body.toString(),
            );
            _seenDocIds.add(docId);
            await prefs.setStringList(_seenDocsKey, _seenDocIds.toList());
          }
        }
      }
    });
  }

  /// Show an instant notification immediately on device screen.
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'zanko_admin_channel',
      'Admin Notifications',
      channelDescription: 'ZankoAI Admin Announcements & Messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF007AFF),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Schedule a notification at [scheduledTime] with given [title] and [body].
  /// [id] should be unique per reminder.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await init();

    // Notify 10 minutes before deadline
    final notifyAt = scheduledTime.subtract(const Duration(minutes: 10));
    if (notifyAt.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(notifyAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'zanko_reminders',
      'Reminders',
      channelDescription: 'ZankoAI deadline reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF007AFF),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification by [id].
  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
