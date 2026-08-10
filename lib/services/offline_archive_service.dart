import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineItemModel {
  final String id;
  final String category; // 'flashcard' | 'summary' | 'quiz'
  final String title;
  final String courseName;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int fileSizeKB;

  OfflineItemModel({
    required this.id,
    required this.category,
    required this.title,
    required this.courseName,
    required this.payload,
    required this.createdAt,
    required this.fileSizeKB,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'courseName': courseName,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'fileSizeKB': fileSizeKB,
    };
  }

  factory OfflineItemModel.fromJson(Map<String, dynamic> map) {
    return OfflineItemModel(
      id: map['id'] ?? '',
      category: map['category'] ?? 'summary',
      title: map['title'] ?? '',
      courseName: map['courseName'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      fileSizeKB: map['fileSizeKB'] ?? 5,
    );
  }
}

class OfflineArchiveService extends ChangeNotifier {
  static final OfflineArchiveService instance = OfflineArchiveService._();
  OfflineArchiveService._();

  static const String _storageKey = 'zanko_offline_archive_items';

  List<OfflineItemModel> _cachedItems = [];

  List<OfflineItemModel> get cachedItems => _cachedItems;

  Future<List<OfflineItemModel>> loadOfflineItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _cachedItems = list.map((e) => OfflineItemModel.fromJson(e)).toList();
      } else {
        _cachedItems = _getMockInitialOfflineItems();
      }
    } catch (_) {
      _cachedItems = _getMockInitialOfflineItems();
    }
    notifyListeners();
    return _cachedItems;
  }

  Future<void> saveOfflineItem({
    required String category,
    required String title,
    required String courseName,
    required Map<String, dynamic> payload,
  }) async {
    final newItem = OfflineItemModel(
      id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      title: title,
      courseName: courseName,
      payload: payload,
      createdAt: DateTime.now(),
      fileSizeKB: (jsonEncode(payload).length / 1024).ceil().clamp(2, 500),
    );

    await loadOfflineItems();
    _cachedItems.insert(0, newItem);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteOfflineItem(String id) async {
    await loadOfflineItems();
    _cachedItems.removeWhere((item) => item.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _cachedItems.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  int getTotalStorageKB() {
    return _cachedItems.fold(0, (sum, item) => sum + item.fileSizeKB);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_cachedItems.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  List<OfflineItemModel> _getMockInitialOfflineItems() {
    return [
      OfflineItemModel(
        id: 'off_1',
        category: 'summary',
        title: 'کورتەی وانەی سیستەمی کارپێکردن',
        courseName: 'سیستەمی کارپێکردن',
        payload: {
          'summaryText': 'سیستەمی کارپێکردن (OS) نەرمەکاڵای سەرەکی کۆمپیوتەرە بەشەکانی بریتیین لە Kernel, Memory Management, Process Scheduling.\n\nخاڵە گرنگەکان:\n١. بەڕێوەبردنی میمۆری\n٢. پرۆسێس و تریدەکان\n٣. بەرگری و ئاسایش',
        },
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        fileSizeKB: 12,
      ),
      OfflineItemModel(
        id: 'off_2',
        category: 'flashcard',
        title: 'فلاش کارتی بنکەی زانیاری',
        courseName: 'داتابەیس',
        payload: {
          'cards': [
            {'front': 'Primary Key چییە؟', 'back': 'کلیلێکی دەستنیشانکەری ناوازەیە لە خشتەی داتابەیسدا.'},
            {'front': 'Foreign Key چییە؟', 'back': 'کلیلێکە لە خشتەیەکدا بەسترابێت بە Primary Key خشتەیەکی ترەوە.'},
            {'front': 'SQL چییە؟', 'back': 'زمانی پرسیارکاریی دارێژراو بۆ داتابەیس (Structured Query Language).'},
          ],
        },
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        fileSizeKB: 8,
      ),
      OfflineItemModel(
        id: 'off_3',
        category: 'quiz',
        title: 'کویزی تاقیکردنەوەی تۆڕەکان',
        courseName: 'تۆڕەکانی کۆمپیوتەر',
        payload: {
          'questions': [
            {
              'question': 'چینی چوارەمی مودێلی OSI چییە؟',
              'options': ['Physical Layer', 'Transport Layer', 'Network Layer', 'Application Layer'],
              'correctIndex': 1,
            },
            {
              'question': 'IP Address لە چەند بەش پێکدێت؟',
              'options': ['4 Octets (32-bits)', '2 Octets', '8 Octets', '128 Octets'],
              'correctIndex': 0,
            },
          ],
        },
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        fileSizeKB: 15,
      ),
    ];
  }
}
