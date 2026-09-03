import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyTaskModel {
  final String id;
  final int dayIndex;
  final String title;
  final String description;
  final int suggestedPomodoros;
  bool isCompleted;

  StudyTaskModel({
    required this.id,
    required this.dayIndex,
    required this.title,
    required this.description,
    required this.suggestedPomodoros,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayIndex': dayIndex,
      'title': title,
      'description': description,
      'suggestedPomodoros': suggestedPomodoros,
      'isCompleted': isCompleted,
    };
  }

  factory StudyTaskModel.fromJson(Map<String, dynamic> json) {
    return StudyTaskModel(
      id: json['id'] ?? '',
      dayIndex: json['dayIndex'] ?? 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      suggestedPomodoros: json['suggestedPomodoros'] ?? 2,
      isCompleted: json['isCompleted'] == true,
    );
  }
}

class StudyRoadmapModel {
  final String id;
  final String subjectName;
  final DateTime examDate;
  final int totalChapters;
  final int hoursPerDay;
  final List<StudyTaskModel> tasks;
  final String advice;

  StudyRoadmapModel({
    required this.id,
    required this.subjectName,
    required this.examDate,
    required this.totalChapters,
    required this.hoursPerDay,
    required this.tasks,
    required this.advice,
  });

  int get daysLeft => examDate.difference(DateTime.now()).inDays.clamp(0, 365);

  double get progressPercentage {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isCompleted).length;
    return (completed / tasks.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectName': subjectName,
      'examDate': examDate.toIso8601String(),
      'totalChapters': totalChapters,
      'hoursPerDay': hoursPerDay,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'advice': advice,
    };
  }

  factory StudyRoadmapModel.fromJson(Map<String, dynamic> json) {
    final taskList = (json['tasks'] as List<dynamic>?)
            ?.map((e) => StudyTaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    return StudyRoadmapModel(
      id: json['id'] ?? '',
      subjectName: json['subjectName'] ?? '',
      examDate: DateTime.tryParse(json['examDate'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      totalChapters: json['totalChapters'] ?? 1,
      hoursPerDay: json['hoursPerDay'] ?? 2,
      tasks: taskList,
      advice: json['advice'] ?? '',
    );
  }
}

class StudyRoadmapService extends ChangeNotifier {
  static final StudyRoadmapService instance = StudyRoadmapService._();
  StudyRoadmapService._();

  static const String _storageKey = 'zanko_study_roadmaps';
  List<StudyRoadmapModel> _roadmaps = [];

  List<StudyRoadmapModel> get roadmaps => _roadmaps;

  Future<List<StudyRoadmapModel>> loadRoadmaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _roadmaps = list.map((e) => StudyRoadmapModel.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        _roadmaps = _getMockInitialRoadmaps();
      }
    } catch (_) {
      _roadmaps = _getMockInitialRoadmaps();
    }
    notifyListeners();
    return _roadmaps;
  }

  Future<void> saveRoadmap(StudyRoadmapModel roadmap) async {
    if (_roadmaps.isEmpty) {
      await loadRoadmaps();
    }
    _roadmaps.insert(0, roadmap);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTaskCompleted(String roadmapId, String taskId) async {
    if (_roadmaps.isEmpty) {
      await loadRoadmaps();
    }
    final roadmapIdx = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (roadmapIdx != -1) {
      final taskIdx = _roadmaps[roadmapIdx].tasks.indexWhere((t) => t.id == taskId);
      if (taskIdx != -1) {
        final task = _roadmaps[roadmapIdx].tasks[taskIdx];
        task.isCompleted = !task.isCompleted;
        await _persist();
        notifyListeners();
      }
    }
  }

  Future<void> deleteRoadmap(String roadmapId) async {
    if (_roadmaps.isEmpty) {
      await loadRoadmaps();
    }
    _roadmaps.removeWhere((r) => r.id == roadmapId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_roadmaps.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  List<StudyRoadmapModel> _getMockInitialRoadmaps() {
    return [
      StudyRoadmapModel(
        id: 'rm_1',
        subjectName: 'سیستەمی کارپێکردن (OS)',
        examDate: DateTime.now().add(const Duration(days: 5)),
        totalChapters: 6,
        hoursPerDay: 3,
        advice: 'پێویستە زۆرتر جەخت لەسەر Memory Management و Deadlocks بکەیتەوە چونکە بەردەوام لە تاقیکردنەوەدا دێن.',
        tasks: [
          StudyTaskModel(
            id: 't1',
            dayIndex: 1,
            title: 'خوێندنی بەشی ١ و ٢ (Processes & Threads)',
            description: 'تێگەیشتن لە جیاوازی نێوان Process و Thread لەگەڵ CPU Scheduling.',
            suggestedPomodoros: 4,
            isCompleted: true,
          ),
          StudyTaskModel(
            id: 't2',
            dayIndex: 2,
            title: 'خوێندنی بەشی ٣ (Process Synchronization)',
            description: 'تێگەیشتن لە Semaphores و Mutex و Critical Section Problem.',
            suggestedPomodoros: 3,
            isCompleted: true,
          ),
          StudyTaskModel(
            id: 't3',
            dayIndex: 3,
            title: 'خوێندنی بەشی ٤ و ٥ (Memory Management & Virtual Memory)',
            description: 'تێگەیشتن لە Paging, Segmentation, Page Faults.',
            suggestedPomodoros: 4,
            isCompleted: false,
          ),
          StudyTaskModel(
            id: 't4',
            dayIndex: 4,
            title: 'پێداچوونەوەی تاقیکردنەوەکانی ساڵانی پێشوو',
            description: 'حەلکردنی پرسیارە کردارەکییەکانی پۆما و کات و بیرکاری OS.',
            suggestedPomodoros: 3,
            isCompleted: false,
          ),
        ],
      ),
    ];
  }
}
