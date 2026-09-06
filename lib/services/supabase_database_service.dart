import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/reminder_model.dart';
import '../models/lecture_model.dart';
import '../models/announcement_model.dart';
import 'database_service.dart';

class SupabaseDatabaseService extends ChangeNotifier implements DatabaseService {
  SupabaseClient get _supabase => Supabase.instance.client;

  final List<NoteModel> _notes = [];
  final List<ScheduleModel> _schedule = [];
  final List<QuizModel> _quizzes = [];
  final List<FlashcardModel> _flashcards = [];
  final List<ReminderModel> _reminders = [];
  final List<Map<String, dynamic>> _enrollmentRequests = [];
  final List<LectureModel> _lectures = [];
  final List<AnnouncementModel> _announcements = [];
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _courses = [];

  int _completedPomodoros = 0;
  int _quizzesTaken = 0;
  int _flashcardsFlipped = 0;

  @override
  List<NoteModel> get notes => _notes;
  @override
  List<ScheduleModel> get schedule => _schedule;
  @override
  List<QuizModel> get quizzes => _quizzes;
  @override
  List<FlashcardModel> get flashcards => _flashcards;
  @override
  List<ReminderModel> get reminders => _reminders;
  @override
  List<Map<String, dynamic>> get enrollmentRequests => _enrollmentRequests;
  @override
  List<LectureModel> get lectures => _lectures;
  @override
  List<AnnouncementModel> get announcements => _announcements;
  @override
  List<Map<String, dynamic>> get departments => _departments;
  @override
  List<Map<String, dynamic>> get courses => _courses;

  @override
  int get completedPomodoros => _completedPomodoros;
  @override
  int get quizzesTaken => _quizzesTaken;
  @override
  int get flashcardsFlipped => _flashcardsFlipped;

  String? get _userId => _supabase.auth.currentUser?.id;

  SupabaseDatabaseService() {
    loadData();
  }

  @override
  Future<void> loadData() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      // 1. Fetch Notes
      final notesData = await _supabase
          .from('notes')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      _notes.clear();
      for (final item in notesData) {
        _notes.add(
          NoteModel(
            id: item['id'].toString(),
            title: item['title'] ?? '',
            content: item['content'] ?? '',
            createdAt: item['created_at'] != null ? DateTime.parse(item['created_at']) : DateTime.now(),
            isAiFormatted: item['is_ai_formatted'] ?? false,
            courseName: item['course_name'],
          ),
        );
      }

      // 2. Fetch Reminders
      final remData = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .order('deadline', ascending: true);

      _reminders.clear();
      for (final item in remData) {
        _reminders.add(
          ReminderModel(
            id: item['id'].toString(),
            title: item['title'] ?? '',
            deadline: item['deadline'] != null ? DateTime.parse(item['deadline']) : DateTime.now(),
            courseName: item['course_name'],
            isCompleted: item['is_completed'] ?? false,
          ),
        );
      }

      // 3. Fetch Flashcards
      final flashData = await _supabase
          .from('flashcards')
          .select()
          .order('created_at', ascending: false);

      _flashcards.clear();
      for (final item in flashData) {
        _flashcards.add(
          FlashcardModel(
            id: item['id'].toString(),
            front: item['front'] ?? '',
            back: item['back'] ?? '',
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Notice loading Supabase database: $e');
    }
  }

  @override
  Future<void> addNote(NoteModel note) async {
    final uid = _userId;
    _notes.insert(0, note);
    notifyListeners();

    if (uid != null) {
      try {
        await _supabase.from('notes').insert({
          'user_id': uid,
          'title': note.title,
          'content': note.content,
          'is_ai_formatted': note.isAiFormatted,
        });
      } catch (e) {
        debugPrint('Supabase insert note error: $e');
      }
    }
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      notifyListeners();
    }

    try {
      await _supabase.from('notes').update({
        'title': note.title,
        'content': note.content,
        'is_ai_formatted': note.isAiFormatted,
      }).eq('id', note.id);
    } catch (_) {}
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    notifyListeners();

    try {
      await _supabase.from('notes').delete().eq('id', noteId);
    } catch (_) {}
  }

  @override
  Future<void> addScheduleItem(ScheduleModel item) async {
    _schedule.add(item);
    notifyListeners();
  }

  @override
  Future<void> deleteScheduleItem(String itemId) async {
    _schedule.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  @override
  Future<void> addQuiz(QuizModel quiz) async {
    _quizzes.insert(0, quiz);
    _quizzesTaken++;
    notifyListeners();
  }

  @override
  Future<void> addFlashcard(FlashcardModel card) async {
    _flashcards.add(card);
    _flashcardsFlipped++;
    notifyListeners();
  }

  @override
  Future<void> clearFlashcards() async {
    _flashcards.clear();
    notifyListeners();
  }

  @override
  Future<void> addReminder(ReminderModel reminder) async {
    final uid = _userId;
    _reminders.insert(0, reminder);
    notifyListeners();

    if (uid != null) {
      try {
        await _supabase.from('reminders').insert({
          'user_id': uid,
          'title': reminder.title,
          'deadline': reminder.deadline.toIso8601String(),
          'course_name': reminder.courseName,
          'is_completed': reminder.isCompleted,
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> toggleReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updated = _reminders[index].copyWith(isCompleted: !_reminders[index].isCompleted);
      _reminders[index] = updated;
      notifyListeners();

      try {
        await _supabase.from('reminders').update({'is_completed': updated.isCompleted}).eq('id', id);
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();

    try {
      await _supabase.from('reminders').delete().eq('id', id);
    } catch (_) {}
  }

  @override
  Future<void> addLecture(LectureModel lecture) async {
    _lectures.insert(0, lecture);
    notifyListeners();
  }

  @override
  Future<void> deleteLecture(String id) async {
    _lectures.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  @override
  Future<void> addAnnouncement(AnnouncementModel announcement) async {
    _announcements.insert(0, announcement);
    notifyListeners();
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    _announcements.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  @override
  Future<void> requestEnrollment(String studentName, String studentEmail, String courseName, String teacherName) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _enrollmentRequests.add({
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': courseName,
      'teacherName': teacherName,
      'status': 'pending',
      'createdAt': DateTime.now(),
    });
    notifyListeners();
  }

  @override
  Future<void> approveEnrollment(String requestId) async {
    final index = _enrollmentRequests.indexWhere((r) => r['id'] == requestId);
    if (index != -1) {
      _enrollmentRequests[index]['status'] = 'approved';
      notifyListeners();
    }
  }

  @override
  Future<void> rejectEnrollment(String requestId) async {
    final index = _enrollmentRequests.indexWhere((r) => r['id'] == requestId);
    if (index != -1) {
      _enrollmentRequests[index]['status'] = 'rejected';
      notifyListeners();
    }
  }

  @override
  void incrementPomodoros() {
    _completedPomodoros++;
    notifyListeners();
  }

  @override
  void incrementQuizzesTaken() {
    _quizzesTaken++;
    notifyListeners();
  }

  @override
  void incrementFlashcardsFlipped() {
    _flashcardsFlipped++;
    notifyListeners();
  }
}
